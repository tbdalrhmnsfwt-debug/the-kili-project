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
 * Foreground service that keeps the app's long AI jobs alive.
 *
 * The original APK declares `com.zaker.zaker_ai.AiJobService` with the
 * `dataSync` and `specialUse` foreground-service types.  The Dart side
 * enqueues jobs through the `zaker.aiJobs.running.v1` shared-preferences
 * key, and the `ZToolsWidget` home-screen widget polls the same store to
 * show progress.
 *
 * The service is deliberately thin: it owns the notification channel and
 * the foreground lifetime, while the actual work happens in Dart.  A
 * platform channel (`zaker/ai_jobs`) lets Dart report progress and the
 * service mirrors that into the notification.
 */
class AiJobService : Service() {

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // `Service.onStartCommand` is the platform method; there is no
        // superclass behaviour to delegate to here.
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: getString(R.string.ai_job_default_title)
        val progress = intent?.getIntExtra(EXTRA_PROGRESS, 0) ?: 0

        val notification = buildNotification(title, progress)
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            notification,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            } else {
                0
            },
        )
        return START_STICKY
    }

    /** Started-only service: nothing binds to it. */
    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.ai_job_channel_name),
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.setShowBadge(false)
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(title: String, progress: Int): Notification {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pending = if (launch != null) {
            PendingIntent.getActivity(
                this,
                0,
                launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        } else {
            null
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setProgress(100, progress.coerceIn(0, 100), progress <= 0)
            .setContentIntent(pending)
            .build()
    }

    companion object {
        const val CHANNEL_ID = "zaker_ai_jobs"
        const val NOTIFICATION_ID = 4711

        const val EXTRA_TITLE = "title"
        const val EXTRA_PROGRESS = "progress"

        /** Starts (or updates) the foreground service. */
        fun start(context: Context, title: String, progress: Int = 0) {
            val intent = Intent(context, AiJobService::class.java)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_PROGRESS, progress)
            androidx.core.content.ContextCompat.startForegroundService(context, intent)
        }

        /** Stops the foreground service. */
        fun stop(context: Context) {
            context.stopService(Intent(context, AiJobService::class.java))
        }
    }
}
