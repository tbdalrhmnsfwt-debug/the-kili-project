package com.zaker.zaker_ai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/**
 * Foreground service that records a lecture.
 *
 * The original APK declares `com.zaker.zaker_ai.LectureRecordService` with
 * the `microphone` foreground-service type, matching the
 * `FOREGROUND_SERVICE_MICROPHONE` permission and the
 * `RECORD_AUDIO` permission in the recovered manifest.
 *
 * Recording itself is done by the Flutter side (the app bundles
 * `ffmpeg_kit_flutter_new_min_gpl` and `sherpa_onnx` for ASR).  This
 * service exists to hold the foreground lifetime and to keep the
 * microphone-typed foreground notification visible while recording.
 */
class LectureRecordService : Service() {

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // A restart with no intent means the process came back after the
        // system killed it. There is no recording to describe and no Dart
        // side waiting for this notification: posting a phantom "recording"
        // bar and staying sticky is worse than stopping.
        if (intent == null) {
            stopSelf(startId)
            return START_NOT_STICKY
        }
        val elapsed = intent.getLongExtra(EXTRA_ELAPSED_MS, 0L)
        val notification = buildNotification(elapsed)

        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            notification,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            } else {
                0
            },
        )
        return START_NOT_STICKY
    }

    /** Started-only service: nothing binds to it. */
    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(elapsedMs: Long): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                getString(R.string.recording_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            )
            channel.setShowBadge(false)
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }

        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pending = launch?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        val seconds = elapsedMs / 1000
        val label = "%02d:%02d".format(seconds / 60, seconds % 60)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.recording_title))
            .setContentText(label)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pending)
            .build()
    }

    companion object {
        const val CHANNEL_ID = "zaker_lecture_record"
        const val NOTIFICATION_ID = 4712

        const val EXTRA_ELAPSED_MS = "elapsed_ms"

        fun start(context: Context, elapsedMs: Long = 0L) {
            val intent = Intent(context, LectureRecordService::class.java)
                .putExtra(EXTRA_ELAPSED_MS, elapsedMs)
            androidx.core.content.ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, LectureRecordService::class.java))
        }
    }
}
