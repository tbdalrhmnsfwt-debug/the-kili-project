package com.zaker.zaker_ai

import android.os.Bundle
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
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Keep the screen on while a focus session or a recording is running.
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    companion object {
        /** Channel used by Dart to drive the AI-job notification. */
        const val AI_JOBS_CHANNEL = "zaker/ai_jobs"
    }
}
