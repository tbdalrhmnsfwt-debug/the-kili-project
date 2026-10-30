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
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

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

    /**
     * Answers adhan-start calls whose service never reported an outcome.
     * Separate from [previewHandler], which `stopPreview` clears wholesale.
     */
    private val startHandler = Handler(Looper.getMainLooper())

    /** Batch audio playback and voice-note recording. */
    private var audioPlayerChannel: AudioPlayerChannel? = null
    private var audioRecorderChannel: AudioRecorderChannel? = null

    /** The ongoing prayer bar, and the route a tap asked for. */
    private var prayerStatusChannel: MethodChannel? = null
    private var pendingPrayerRoute: String? = null

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
                        startAiJobService(title, progress)
                        result.success(null)
                    }
                    "updateAiJob" -> {
                        val title = call.argument<String>("title")
                            ?: getString(R.string.ai_job_default_title)
                        val progress = call.argument<Int>("progress") ?: 0
                        startAiJobService(title, progress)
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
                        // The service, not this handler, knows whether the
                        // adhan is audible: report that instead of assuming
                        // a start. The timeout covers a service that dies
                        // before it can answer.
                        var answered = false
                        val answer: (Boolean) -> Unit = { started ->
                            if (!answered) {
                                answered = true
                                result.success(started)
                            }
                        }
                        val timeout = Runnable { answer(false) }
                        startHandler.postDelayed(timeout, ADHAN_START_TIMEOUT_MS)
                        AdhanPlaybackService.start(
                            this,
                            name,
                            asset,
                            title,
                            notificationId,
                            fadeIn,
                            silence,
                            onStarted = { started ->
                                startHandler.removeCallbacks(timeout)
                                answer(started)
                            },
                        )
                    }
                    "stopAdhanPlayback" -> {
                        AdhanPlaybackService.stop(this)
                        result.success(null)
                    }
                    "setKeepScreenOn" -> {
                        // Only the screens that need it (the qibla aim and a
                        // full-screen adhan) ask; everywhere else the screen
                        // follows the system timeout again.
                        setKeepScreenOn(call.argument<Boolean>("on") == true)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Tiled page rendering for the PDF reader.
        PdfRenderChannel(flutterEngine.dartExecutor.binaryMessenger).register()

        // The ongoing prayer bar: Dart hands over the boundary window, and a
        // tap forwards its route once the Dart handler exists.
        pendingPrayerRoute = intent?.getStringExtra("route") ?: pendingPrayerRoute
        prayerStatusChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PrayerStatusBridge.CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "sync" -> result.success(
                        PrayerStatusBridge.sync(this, call.arguments as? Map<*, *>),
                    )
                    "cancel" -> {
                        PrayerStatusBridge.cancel(this)
                        result.success(true)
                    }
                    "takeLaunchRoute" -> {
                        val route = pendingPrayerRoute ?: intent?.getStringExtra("route")
                        pendingPrayerRoute = null
                        intent?.removeExtra("route")
                        result.success(route)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // Audio resources and microphone voice notes for batch chat.
        audioPlayerChannel = AudioPlayerChannel(flutterEngine.dartExecutor.binaryMessenger)
            .also { it.register(this) }
        audioRecorderChannel = AudioRecorderChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            this,
        ).also { it.register() }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (audioRecorderChannel?.onRequestPermissionsResult(requestCode, grantResults) == true) {
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The screen flag is set per screen through `setKeepScreenOn`, not
        // here: keeping every screen awake drained the battery on the home
        // screen and everywhere else the student never asked for it.
        sweepOrphanRecordings()
        showOverLockScreenIfAdhan(intent)
    }

    /**
     * Removes recordings a day old or more.
     *
     * Voice notes are recorded into `cacheDir/recordings` and copied into the
     * batch before Dart deletes the temporary file. A clip whose send failed,
     * or whose app was killed mid-send, is never consumed and would sit in the
     * cache until the system evicted it.
     */
    private fun sweepOrphanRecordings() {
        val cutoff = System.currentTimeMillis() - RECORDING_MAX_AGE_MS
        try {
            for (file in File(cacheDir, "recordings").listFiles().orEmpty()) {
                if (file.isFile && file.lastModified() < cutoff) file.delete()
            }
        } catch (_: Exception) {
            // A cache that cannot be listed is not worth a crash on startup.
        }
    }

    /**
     * Starts or refreshes the AI-job notification.
     *
     * Android 12+ refuses a foreground-service start from the background, and
     * a progress update can arrive after the student left the app. The job
     * itself keeps running in Dart either way, so a refused start is not an
     * error worth surfacing — and it cannot be allowed to throw, because an
     * exception in a channel handler takes the process down.
     */
    private fun startAiJobService(title: String, progress: Int) {
        try {
            AiJobService.start(this, title, progress)
        } catch (_: Exception) {
            // No notification; the job still completes in Dart.
        }
    }

    /** Adds or clears `FLAG_KEEP_SCREEN_ON` for the current screen. */
    private fun setKeepScreenOn(on: Boolean) {
        runOnUiThread {
            if (on) {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        showOverLockScreenIfAdhan(intent)
        val route = intent.getStringExtra("route")
        if (route != null) {
            pendingPrayerRoute = route
            prayerStatusChannel?.invokeMethod("openRoute", route)
        }
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
        prayerStatusChannel?.setMethodCallHandler(null)
        prayerStatusChannel = null
        audioPlayerChannel?.dispose()
        audioRecorderChannel?.dispose()
        audioPlayerChannel = null
        audioRecorderChannel = null
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
        /** How long a start call waits for the service to report an outcome. */
        const val ADHAN_START_TIMEOUT_MS = 4000L

        /** Orphaned voice recordings are swept once they are this old. */
        const val RECORDING_MAX_AGE_MS = 24 * 60 * 60 * 1000L

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
