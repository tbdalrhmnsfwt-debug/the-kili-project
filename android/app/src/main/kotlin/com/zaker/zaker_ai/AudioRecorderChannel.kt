package com.zaker.zaker_ai

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.media.MediaMetadataRetriever
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Records a mono AAC voice note into the app-private cache directory.
 *
 * The microphone permission is requested at runtime; a denied permission is
 * reported as `permissionDenied` and leaves every other feature usable. The
 * file name supplied by Dart is resolved inside this app's cache only, so a
 * crafted path cannot escape into another app's storage.
 */
class AudioRecorderChannel(
    messenger: BinaryMessenger,
    private val activity: Activity,
) {

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private val main = Handler(Looper.getMainLooper())

    private var recorder: MediaRecorder? = null
    private var output: File? = null
    private var startedAt = 0L
    private var eventSink: EventChannel.EventSink? = null
    private var pendingPermission: MethodChannel.Result? = null
    private var pendingClip: Map<String, Any>? = null
    private var lastNotifiedSecond = -1L

    private val ticker = object : Runnable {
        override fun run() {
            val active = recorder ?: return
            val amplitude = try {
                active.maxAmplitude
            } catch (_: IllegalStateException) {
                0
            }
            val elapsed = SystemClock.elapsedRealtime() - startedAt
            val seconds = elapsed / 1000
            if (seconds >= 5 && seconds / 5 != lastNotifiedSecond / 5) {
                lastNotifiedSecond = seconds
                // Refreshing the foreground notification keeps the timer
                // honest while the app is in the background.
                try {
                    LectureRecordService.start(activity, elapsed)
                } catch (_: Exception) {
                    // The notification is optional; recording stays valid.
                }
            }
            emitTick(elapsed, amplitude, false)
            main.postDelayed(this, TICK_MS)
        }
    }

    fun register() {
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(hasPermission())
                "requestPermission" -> requestPermission(result)
                "freeBytes" -> result.success(availableBytes())
                "start" -> start(call, result)
                "stop" -> stop(result)
                "cancel" -> {
                    cancel()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                eventSink = sink
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    /** Called from the activity's permission callback. */
    fun onRequestPermissionsResult(
        requestCode: Int,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        val result = pendingPermission ?: return true
        pendingPermission = null
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        result.success(granted)
        return true
    }

    fun dispose() {
        cancel()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        pendingPermission?.error("cancelled", null, null)
        pendingPermission = null
    }

    private fun hasPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestPermission(result: MethodChannel.Result) {
        if (hasPermission()) {
            result.success(true)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success(false)
            return
        }
        if (pendingPermission != null) {
            pendingPermission?.error("cancelled", null, null)
        }
        pendingPermission = result
        try {
            activity.requestPermissions(
                arrayOf(Manifest.permission.RECORD_AUDIO),
                PERMISSION_REQUEST,
            )
        } catch (error: Exception) {
            pendingPermission = null
            result.error("permissionDenied", null, null)
        }
    }

    private fun availableBytes(): Long {
        return try {
            activity.cacheDir.usableSpace.coerceAtLeast(0)
        } catch (error: Exception) {
            0
        }
    }

    private fun start(call: MethodCall, result: MethodChannel.Result) {
        if (!hasPermission()) {
            result.error("permissionDenied", null, null)
            return
        }
        if (recorder != null) {
            result.error("alreadyRecording", null, null)
            return
        }
        val raw = call.argument<String>("path")
        val target = resolveTemp(raw, result) ?: return
        target.parentFile?.mkdirs()
        val created = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(activity)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        try {
            created.setAudioSource(MediaRecorder.AudioSource.MIC)
            created.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            created.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            created.setAudioSamplingRate(44_100)
            created.setAudioEncodingBitRate(64_000)
            created.setAudioChannels(1)
            created.setMaxDuration(MAX_DURATION_MS.toInt())
            created.setOutputFile(target.absolutePath)
            created.setOnInfoListener { _, what, _ ->
                if (what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED) {
                    stopAtLimit()
                }
            }
            created.prepare()
            created.start()
        } catch (error: Exception) {
            try {
                created.release()
            } catch (_: Exception) {
            }
            target.delete()
            result.error("recordFailed", null, null)
            return
        }
        recorder = created
        output = target
        startedAt = SystemClock.elapsedRealtime()
        lastNotifiedSecond = -1L
        pendingClip = null
        try {
            // A microphone-typed foreground service keeps the recording legal
            // when the user leaves the app mid-note.
            LectureRecordService.start(activity, 0L)
        } catch (_: Exception) {
            // Recording still works while the app stays in front.
        }
        main.removeCallbacks(ticker)
        main.postDelayed(ticker, TICK_MS)
        result.success(null)
    }

    private fun stop(result: MethodChannel.Result) {
        val cached = pendingClip
        if (cached != null) {
            pendingClip = null
            result.success(cached)
            return
        }
        val clip = stopInternal()
        if (clip == null) {
            result.error("recordFailed", null, null)
        } else {
            result.success(clip)
        }
    }

    private fun stopAtLimit() {
        if (recorder == null) return
        pendingClip = stopInternal()
        emitTick(MAX_DURATION_MS, 0, true)
    }

    /** Stops and returns the clip map, or null when no readable file exists. */
    private fun stopInternal(): Map<String, Any>? {
        val active = recorder
        val target = output
        recorder = null
        output = null
        cancelTicker()
        try {
            LectureRecordService.stop(activity)
        } catch (_: Exception) {
            // The service may already have been stopped with the activity.
        }
        if (active == null || target == null) return null
        var stopped = false
        try {
            active.stop()
            stopped = true
        } catch (_: RuntimeException) {
            // Stopping too early throws; the file is kept only if it is real.
        } finally {
            try {
                active.release()
            } catch (_: Exception) {
            }
        }
        if (!stopped || !target.isFile || target.length() <= 0) {
            target.delete()
            return null
        }
        val elapsed = (SystemClock.elapsedRealtime() - startedAt).coerceAtLeast(0)
        val duration = durationOf(target) ?: elapsed
        return mapOf(
            "path" to target.absolutePath,
            "durationMs" to duration,
            "sizeBytes" to target.length(),
        )
    }

    private fun durationOf(file: File): Int? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(file.absolutePath)
            val raw = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_DURATION,
            )
            raw?.toIntOrNull()?.takeIf { it > 0 }
        } catch (_: Exception) {
            null
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {
            }
        }
    }

    private fun cancel() {
        val active = recorder
        recorder = null
        cancelTicker()
        try {
            LectureRecordService.stop(activity)
        } catch (_: Exception) {
            // The service may already be gone with the activity.
        }
        if (active != null) {
            try {
                active.stop()
            } catch (_: RuntimeException) {
            }
            try {
                active.release()
            } catch (_: Exception) {
            }
        }
        output?.delete()
        output = null
        pendingClip = null
    }

    private fun resolveTemp(
        raw: String?,
        result: MethodChannel.Result,
    ): File? {
        if (raw.isNullOrBlank()) {
            result.error("recordFailed", null, null)
            return null
        }
        val cacheRoot = activity.cacheDir
        val candidate = if (File(raw).isAbsolute) {
            File(raw)
        } else {
            File(File(cacheRoot, "recordings"), raw)
        }
        return try {
            val root = cacheRoot.canonicalFile
            val target = candidate.canonicalFile
            val parent = target.parentFile?.canonicalPath.orEmpty()
            val inside = parent == root.canonicalPath ||
                parent.startsWith(root.canonicalPath + File.separator)
            if (!inside) {
                result.error("recordFailed", null, null)
                null
            } else {
                target
            }
        } catch (error: Exception) {
            result.error("recordFailed", null, null)
            null
        }
    }

    private fun emitTick(elapsedMs: Long, amplitude: Int, maxReached: Boolean) {
        val payload = HashMap<String, Any>()
        payload["elapsedMs"] = elapsedMs
        payload["amplitude"] = amplitude
        payload["maxReached"] = maxReached
        eventSink?.success(payload)
    }

    private fun cancelTicker() {
        main.removeCallbacks(ticker)
    }

    private companion object {
        const val METHOD_CHANNEL = "zaker/audio_recorder"
        const val EVENT_CHANNEL = "zaker/recorder_events"
        const val PERMISSION_REQUEST = 4211
        const val TICK_MS = 200L
        const val MAX_DURATION_MS = 15 * 60 * 1000L
    }
}
