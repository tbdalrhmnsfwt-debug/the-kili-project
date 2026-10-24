package com.zaker.zaker_ai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

/**
 * Plays the adhan in a foreground service.
 *
 * The full-screen adhan starts this service as soon as it opens, so the
 * recording keeps playing when the screen is turned off or the app is sent to
 * the background.  The ongoing notification carries the "إيقاف الأذان" action,
 * which stops the service; closing the full-screen player does the same.
 *
 * The recording is read from `res/raw` for the bundled voices, or from the
 * Flutter asset bundle for a recording the user added under
 * `assets/adhan/egyptian_*.mp3`.
 */
class AdhanPlaybackService : Service() {

    private var player: MediaPlayer? = null
    private var focusRequest: AudioFocusRequest? = null
    private var legacyFocusHeld = false
    private val handler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START -> {
                val title = intent?.getStringExtra(EXTRA_TITLE)
                    ?: getString(R.string.adhan_playing_title)
                ServiceCompat.startForeground(
                    this,
                    NOTIFICATION_ID,
                    buildNotification(title),
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                    } else {
                        0
                    },
                )
                play(
                    intent?.getStringExtra(EXTRA_RESOURCE),
                    intent?.getStringExtra(EXTRA_ASSET),
                )
            }
        }
        return START_NOT_STICKY
    }

    /** Started-only service: nothing binds to it. */
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        releasePlayer()
        super.onDestroy()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.adhan_playing_channel),
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.setSound(null, null)
        channel.enableVibration(false)
        channel.setShowBadge(false)
        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    private fun buildNotification(title: String): Notification {
        val stopIntent = Intent(this, AdhanPlaybackService::class.java)
            .setAction(ACTION_STOP)
        val stopPending = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val contentPending = launch?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(getString(R.string.adhan_playing_text))
            .setSmallIcon(R.drawable.ic_adhan_notification)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .addAction(R.drawable.ic_adhan_stop, getString(R.string.adhan_stop), stopPending)
            .setContentIntent(contentPending)
            .build()
    }

    private fun play(resource: String?, asset: String?) {
        releasePlayer()
        val created = try {
            createPlayer(resource, asset)
        } catch (e: Exception) {
            null
        }
        if (created == null) {
            stopSelf()
            return
        }

        player = created
        requestFocus()
        created.setOnCompletionListener { stopSelf() }
        created.setOnErrorListener { _, _, _ ->
            stopSelf()
            true
        }
        try {
            created.start()
        } catch (e: Exception) {
            stopSelf()
            return
        }
        handler.postDelayed({
            if (player === created) stopSelf()
        }, MAX_PLAY_MS)
    }

    private fun createPlayer(resource: String?, asset: String?): MediaPlayer? {
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        val created = MediaPlayer()
        created.setAudioAttributes(attributes)
        created.setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)

        val rawId = if (resource.isNullOrBlank()) {
            0
        } else {
            resources.getIdentifier(resource, "raw", packageName)
        }
        if (rawId != 0) {
            val descriptor = resources.openRawResourceFd(rawId)
            descriptor.use {
                created.setDataSource(it.fileDescriptor, it.startOffset, it.length)
            }
        } else if (!asset.isNullOrBlank()) {
            // Flutter assets are packaged under `flutter_assets/`.
            val path = if (asset.startsWith(ASSET_PREFIX)) {
                "flutter_assets/$asset"
            } else {
                "flutter_assets/assets/$asset"
            }
            val descriptor = assets.openFd(path)
            descriptor.use {
                created.setDataSource(it.fileDescriptor, it.startOffset, it.length)
            }
        } else {
            created.release()
            return null
        }

        created.prepare()
        return created
    }

    private fun requestFocus() {
        val manager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            val granted = manager.requestAudioFocus(
                null,
                AudioManager.STREAM_ALARM,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT,
            ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
            legacyFocusHeld = granted
            return
        }
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            .setAudioAttributes(attributes)
            .setOnAudioFocusChangeListener { }
            .build()
        focusRequest = request
        manager.requestAudioFocus(request)
    }

    private fun releasePlayer() {
        val current = player ?: return
        player = null
        try {
            if (current.isPlaying) current.stop()
        } catch (_: IllegalStateException) {
            // Already stopped; releasing below is still safe.
        } finally {
            current.release()
        }
        focusRequest?.let { request ->
            val manager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            manager.abandonAudioFocusRequest(request)
        }
        focusRequest = null
        if (legacyFocusHeld) {
            legacyFocusHeld = false
            @Suppress("DEPRECATION")
            (getSystemService(Context.AUDIO_SERVICE) as AudioManager)
                .abandonAudioFocus(null)
        }
    }

    companion object {
        const val ACTION_START = "com.zaker.zaker_ai.adhan.START"
        const val ACTION_STOP = "com.zaker.zaker_ai.adhan.STOP"

        const val EXTRA_RESOURCE = "resource"
        const val EXTRA_ASSET = "asset"
        const val EXTRA_TITLE = "title"

        private const val CHANNEL_ID = "zaker_adhan_playback"
        private const val NOTIFICATION_ID = 7001
        private const val ASSET_PREFIX = "assets/"

        /** Longest single playback; the bundled recordings are < 4 minutes. */
        private const val MAX_PLAY_MS = 8 * 60 * 1000L

        /** Starts (or restarts) the playback service. */
        fun start(context: Context, resource: String?, asset: String?, title: String) {
            val intent = Intent(context, AdhanPlaybackService::class.java)
                .setAction(ACTION_START)
                .putExtra(EXTRA_RESOURCE, resource)
                .putExtra(EXTRA_ASSET, asset)
                .putExtra(EXTRA_TITLE, title)
            ContextCompat.startForegroundService(context, intent)
        }

        /** Stops playback and removes the ongoing notification. */
        fun stop(context: Context) {
            context.stopService(Intent(context, AdhanPlaybackService::class.java))
        }
    }
}
