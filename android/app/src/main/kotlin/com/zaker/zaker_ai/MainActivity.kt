package com.zaker.zaker_ai

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The app's single activity.
 *
 * The original APK also declares `com.pairip.licensecheck.LicenseActivity`
 * and an `AudioServiceActivity` (from `just_audio`); both are pulled in by
 * the plugins and are not part of the replica.
 */
class MainActivity : FlutterActivity() {

    /** Plays one of the bundled `res/raw` adhan files for the voice picker. */
    private var previewPlayer: MediaPlayer? = null
    private val previewHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // The AI job service mirrors Dart-side progress into its
        // notification.  Dart pushes updates through this channel.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AI_JOBS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startAiJob" -> {
                        val title = call.argument<String>("title")
                            ?: getString(R.string.ai_job_default_title)
                        val progress = call.argument<Int>("progress") ?: 0
                        AiJobService.start(this, title, progress)
                        result.success(null)
                    }
                    "updateAiJob" -> {
                        val title = call.argument<String>("title")
                            ?: getString(R.string.ai_job_default_title)
                        val progress = call.argument<Int>("progress") ?: 0
                        AiJobService.start(this, title, progress)
                        result.success(null)
                    }
                    "stopAiJob" -> {
                        AiJobService.stop(this)
                        result.success(null)
                    }
                    "startRecording" -> {
                        val elapsed = call.argument<Long>("elapsedMs") ?: 0L
                        LectureRecordService.start(this, elapsed)
                        result.success(null)
                    }
                    "stopRecording" -> {
                        LectureRecordService.stop(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Battery-optimisation state, the app's settings page and the in-app
        // adhan preview used by the prayer notification settings.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ADHAN_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" ->
                        result.success(isIgnoringBatteryOptimizations())
                    "requestIgnoreBatteryOptimizations" -> {
                        val intent = Intent(
                            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                            Uri.parse("package:$packageName")
                        )
                        result.success(startSafely(intent))
                    }
                    "openAppSettings" -> {
                        val intent = Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:$packageName")
                        )
                        result.success(startSafely(intent))
                    }
                    "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent())
                    "requestFullScreenIntent" -> result.success(startSafely(fullScreenIntentSettings()))
                    "canDrawOverlays" -> result.success(Settings.canDrawOverlays(this))
                    "requestOverlayPermission" -> {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        result.success(startSafely(intent))
                    }
                    "playPreview" -> {
                        val name = call.argument<String>("name")
                        val asset = call.argument<String>("asset")
                        result.success(playPreview(name, asset))
                    }
                    "stopPreview" -> {
                        stopPreview()
                        result.success(null)
                    }
                    "startAdhanPlayback" -> {
                        val name = call.argument<String>("name")
                        val asset = call.argument<String>("asset")
                        val title = call.argument<String>("title")
                            ?: getString(R.string.adhan_playing_title)
                        val notificationId = call.argument<Int>("notificationId") ?: 0
                        val fadeIn = call.argument<Boolean>("fadeIn") == true
                        val silence = call.argument<Boolean>("silenceOnHardware") != false
                        AdhanPlaybackService.start(
                            this,
                            name,
                            asset,
                            title,
                            notificationId,
                            fadeIn,
                            silence,
                        )
                        result.success(true)
                    }
                    "stopAdhanPlayback" -> {
                        AdhanPlaybackService.stop(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Tiled page rendering for the PDF reader.
        PdfRenderChannel(flutterEngine.dartExecutor.binaryMessenger).register()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Keep the screen on while a focus session or a recording is running.
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        showOverLockScreenIfAdhan(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        showOverLockScreenIfAdhan(intent)
    }

    /**
     * A full-screen adhan has to appear over the lock screen and turn the
     * display on.  Every other launch clears those flags again, so an ordinary
     * notification or the launcher behaves normally.
     */
    private fun showOverLockScreenIfAdhan(intent: Intent?) {
        val payload = intent?.getStringExtra("payload")
        val isAdhan = payload != null && payload.contains("\"type\":\"adhan\"")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(isAdhan)
            setTurnScreenOn(isAdhan)
        }
    }

    override fun onResume() {
        super.onResume()
        isForeground = true
        AdhanPlaybackService.hideFloatingCard()
    }

    override fun onPause() {
        isForeground = false
        super.onPause()
        // A preview must not keep playing while the app is in the background.
        stopPreview()
    }

    /**
     * Volume keys silence a playing adhan without changing the alarm volume,
     * as requested by the "اكتم الأذان بأزرار الجهاز" setting.  The key event
     * is consumed only while our own playback is active.
     */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val silencing = event.action == KeyEvent.ACTION_DOWN &&
            (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
                event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) &&
            AdhanPlaybackService.isActive &&
            AdhanPlaybackService.hardwareSilenceEnabled
        if (silencing) {
            AdhanPlaybackService.stop(this)
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onDestroy() {
        stopPreview()
        super.onDestroy()
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        return power.isIgnoringBatteryOptimizations(packageName)
    }

    /**
     * Android 14 can withhold the full-screen-intent permission even when the
     * manifest declares it, so the diagnostics screen checks it explicitly.
     */
    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < 34) return true
        return try {
            val manager =
                getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            manager.canUseFullScreenIntent()
        } catch (e: Exception) {
            true
        }
    }

    private fun fullScreenIntentSettings(): Intent {
        if (Build.VERSION.SDK_INT < 34) {
            return Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName")
            )
        }
        return Intent(
            "android.settings.MANAGE_APP_USE_FULL_SCREEN_INTENT",
            Uri.parse("package:$packageName")
        )
    }

    private fun startSafely(intent: Intent): Boolean {
        return try {
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Opens a raw resource, or a Flutter asset for a user-added recording.
     * Raw resources win when both exist, which is the documented way to make
     * an added Egyptian file usable as a notification sound as well.
     */
    private fun createPreviewPlayer(name: String?, asset: String?): MediaPlayer? {
        if (!name.isNullOrBlank()) {
            val id = resources.getIdentifier(name, "raw", packageName)
            if (id != 0) return MediaPlayer.create(this, id)
        }
        if (asset.isNullOrBlank()) return null

        val path = if (asset.startsWith("assets/")) {
            "flutter_assets/$asset"
        } else {
            "flutter_assets/assets/$asset"
        }
        val descriptor = assets.openFd(path)
        val player = MediaPlayer()
        player.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()
        )
        descriptor.use {
            player.setDataSource(it.fileDescriptor, it.startOffset, it.length)
        }
        player.prepare()
        return player
    }

    /**
     * Plays `res/raw/<name>.mp3`, or the Flutter [asset] for a user-added
     * recording, for the voice picker.  Playback stops on completion, after
     * [PREVIEW_TIMEOUT_MS], or when another preview starts.
     */
    private fun playPreview(name: String?, asset: String?): Boolean {
        if (name.isNullOrBlank() && asset.isNullOrBlank()) return false

        stopPreview()
        val player = try {
            createPreviewPlayer(name, asset)
        } catch (e: Exception) {
            null
        } ?: return false

        previewPlayer = player
        player.setOnCompletionListener { stopPreview() }
        player.start()
        previewHandler.postDelayed({
            if (previewPlayer === player) stopPreview()
        }, PREVIEW_TIMEOUT_MS)
        return true
    }

    private fun stopPreview() {
        previewHandler.removeCallbacksAndMessages(null)
        val player = previewPlayer ?: return
        previewPlayer = null
        try {
            if (player.isPlaying) player.stop()
        } catch (_: IllegalStateException) {
            // Already stopped or released; releasing below is still safe.
        } finally {
            player.release()
        }
    }

    companion object {
        /** Channel used by Dart to drive the AI-job notification. */
        const val AI_JOBS_CHANNEL = "zaker/ai_jobs"

        /** Channel for battery settings and the adhan preview player. */
        const val ADHAN_CHANNEL = "zaker/adhan"

        /** Channel used by the PDF reader for clipped page tiles. */
        const val PDF_RENDER_CHANNEL = "zaker/pdf_render"

        /** Longest preview, in milliseconds. */
        private const val PREVIEW_TIMEOUT_MS = 20_000L

        /**
         * Whether this activity is in front, read by the adhan player before
         * it treats an alarm-volume change from another app as "silence me".
         */
        @Volatile
        var isForeground: Boolean = false
            private set
    }
}
