package com.zaker.zaker_ai

import android.graphics.Bitmap
import android.graphics.Matrix
import android.graphics.pdf.LoadParams
import android.graphics.pdf.PdfRenderer
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.util.SparseArray
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.ceil
import kotlin.math.max

/**
 * Renders clipped PDF tiles through `android.graphics.pdf.PdfRenderer`.
 *
 * The reader zooms up to 500% of fit-width, so rendering whole pages would
 * either be blurry or exhaust memory. Dart asks for exactly the visible
 * region plus a prefetch margin and gets PNG bytes back.
 */
class PdfRenderChannel(messenger: BinaryMessenger) {

    private val channel = MethodChannel(messenger, MainActivity.PDF_RENDER_CHANNEL)
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val renderers = SparseArray<PdfRenderer>()
    private val descriptors = SparseArray<ParcelFileDescriptor>()
    private val lock = Any()
    private var nextHandle = 1

    fun register() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "open" -> open(call, result)
                "render" -> render(call, result)
                "close" -> {
                    closeHandle(call.argument<Int>("handle") ?: -1)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Builds a renderer for [descriptor], unlocking it with [password] when
     * the platform supports that.
     *
     * `PdfRenderer` only learned to take a password with `LoadParams` in
     * Android 15; older releases keep the plain constructor, which refuses a
     * protected file with a `SecurityException`.
     */
    private fun openRenderer(
        descriptor: ParcelFileDescriptor,
        password: String?,
    ): PdfRenderer {
        if (Build.VERSION.SDK_INT >= PASSWORD_API) {
            val params = LoadParams.Builder().setPassword(password).build()
            return PdfRenderer(descriptor, params)
        }
        return PdfRenderer(descriptor)
    }

    private fun open(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val password = call.argument<String>("password")
        if (path == null || path.isEmpty()) {
            result.error("corrupt", null, null)
            return
        }
        executor.execute {
            var descriptor: ParcelFileDescriptor? = null
            // Hoisted out of the try so the catch below can release a renderer
            // that was built before the page list or the handle map failed.
            var renderer: PdfRenderer? = null
            try {
                descriptor =
                    ParcelFileDescriptor.open(File(path), ParcelFileDescriptor.MODE_READ_ONLY)
                if (password != null && Build.VERSION.SDK_INT < PASSWORD_API) {
                    // Below Android 15 the platform renderer has no way to
                    // unlock a document, so a correct password would otherwise
                    // be reported as a wrong one.
                    try {
                        descriptor?.close()
                    } catch (_: Exception) {
                    }
                    main.post { result.error("passwordUnsupported", null, null) }
                    return@execute
                }
                val opened =
                    try {
                        openRenderer(descriptor, password)
                    } catch (error: SecurityException) {
                        try {
                            descriptor?.close()
                        } catch (_: Exception) {
                        }
                        val code = if (password == null) "passwordRequired" else "wrongPassword"
                        main.post { result.error(code, null, null) }
                        return@execute
                    }
                renderer = opened

                val pageCount = opened.pageCount
                if (pageCount <= 0) {
                    // A document with no pages cannot be read; answering with an
                    // empty handle would make the reader clamp against zero.
                    try {
                        opened.close()
                    } catch (_: Exception) {
                    }
                    try {
                        descriptor?.close()
                    } catch (_: Exception) {
                    }
                    main.post { result.error("corrupt", null, null) }
                    return@execute
                }

                val pages = ArrayList<Map<String, Double>>(pageCount)
                for (index in 0 until pageCount) {
                    val page = opened.openPage(index)
                    try {
                        pages.add(
                            mapOf(
                                "width" to page.width.toDouble(),
                                "height" to page.height.toDouble(),
                            )
                        )
                    } finally {
                        page.close()
                    }
                }

                val payload = HashMap<String, Any>()
                payload["pageCount"] = pageCount
                payload["pages"] = pages
                synchronized(lock) {
                    val handle = nextHandle++
                    renderers.put(handle, opened)
                    descriptors.put(handle, descriptor)
                    payload["handle"] = handle
                }
                main.post { result.success(payload) }
            } catch (error: Exception) {
                try {
                    renderer?.close()
                } catch (_: Exception) {
                }
                try {
                    descriptor?.close()
                } catch (_: Exception) {
                }
                main.post { result.error("corrupt", null, null) }
            }
        }
    }

    private fun render(call: MethodCall, result: MethodChannel.Result) {
        val handle = call.argument<Int>("handle") ?: -1
        val pageIndex = call.argument<Int>("page") ?: -1
        val scale = call.argument<Double>("scale") ?: 1.0
        val left = call.argument<Double>("left") ?: 0.0
        val top = call.argument<Double>("top") ?: 0.0
        val width = call.argument<Double>("width") ?: 1.0
        val height = call.argument<Double>("height") ?: 1.0
        val maxPixels = call.argument<Int>("maxPixels") ?: 4096

        executor.execute {
            try {
                synchronized(lock) {
                    val renderer = renderers.get(handle)
                    if (renderer == null || pageIndex < 0 || pageIndex >= renderer.pageCount) {
                        main.post { result.error("renderFailed", null, null) }
                        return@execute
                    }
                    val page = renderer.openPage(pageIndex)
                    try {
                        val pageWidth = page.width.toDouble()
                        val pageHeight = page.height.toDouble()
                        var bitmapWidth = ceil(pageWidth * width * scale).toInt()
                        var bitmapHeight = ceil(pageHeight * height * scale).toInt()
                        bitmapWidth = max(1, bitmapWidth)
                        bitmapHeight = max(1, bitmapHeight)

                        val longest = max(bitmapWidth, bitmapHeight)
                        if (longest > maxPixels) {
                            val shrink = maxPixels.toDouble() / longest
                            bitmapWidth = max(1, (bitmapWidth * shrink).toInt())
                            bitmapHeight = max(1, (bitmapHeight * shrink).toInt())
                        }

                        val bitmap = Bitmap.createBitmap(
                            bitmapWidth,
                            bitmapHeight,
                            Bitmap.Config.ARGB_8888,
                        )
                        try {
                            val pixelsPerPointX =
                                bitmapWidth / (pageWidth * max(width, 1e-6))
                            val pixelsPerPointY =
                                bitmapHeight / (pageHeight * max(height, 1e-6))
                            val matrix = Matrix()
                            matrix.postTranslate(
                                (-left * pageWidth).toFloat(),
                                (-top * pageHeight).toFloat(),
                            )
                            matrix.postScale(
                                pixelsPerPointX.toFloat(),
                                pixelsPerPointY.toFloat(),
                            )
                            page.render(
                                bitmap,
                                null,
                                matrix,
                                PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY,
                            )
                            val stream = ByteArrayOutputStream()
                            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                            val bytes = stream.toByteArray()
                            main.post { result.success(bytes) }
                        } finally {
                            bitmap.recycle()
                        }
                    } finally {
                        page.close()
                    }
                }
            } catch (error: Throwable) {
                // Throwable, not Exception: an OutOfMemoryError while
                // allocating the tile would otherwise never answer the
                // awaiting Dart future, and that page would stay blank.
                main.post { result.error("renderFailed", null, null) }
            }
        }
    }

    private fun closeHandle(handle: Int) {
        if (handle < 0) return
        executor.execute {
            synchronized(lock) {
                renderers.get(handle)?.let {
                    try {
                        it.close()
                    } catch (_: Exception) {
                    }
                    renderers.remove(handle)
                }
                descriptors.get(handle)?.let {
                    try {
                        it.close()
                    } catch (_: Exception) {
                    }
                    descriptors.remove(handle)
                }
            }
        }
    }

    private companion object {
        /** The first Android release whose [PdfRenderer] accepts a password. */
        const val PASSWORD_API = 35
    }
}
