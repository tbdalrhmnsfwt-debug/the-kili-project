package com.zaker.zaker_ai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.database.ContentObserver
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.text.TextUtils
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
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

    /** Whether the phone's own controls may silence this playback. */
    private var silenceOnHardware = true

    /** The plugin notification that launched this player, cancelled on stop. */
    private var sourceNotificationId = 0

    /** Gentle fade-in, default on for Fajr. */
    private var fadeIn = false
    private var fadeStep = 0

    private var screenReceiver: BroadcastReceiver? = null
    private var volumeObserver: ContentObserver? = null
    private var lastAlarmVolume = -1
    private var overlayView: View? = null
    private val fadeRunnable = object : Runnable {
        override fun run() {
            val current = player ?: return
            fadeStep++
            val level = (fadeStep / FADE_STEPS.toFloat()).coerceIn(0f, 1f)
            try {
                current.setVolume(level, level)
            } catch (_: IllegalStateException) {
                return
            }
            if (fadeStep < FADE_STEPS) {
                handler.postDelayed(this, FADE_STEP_MS)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
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
                fadeIn = intent?.getBooleanExtra(EXTRA_FADE_IN, false) == true
                silenceOnHardware =
                    intent?.getBooleanExtra(EXTRA_SILENCE_ON_HARDWARE, true) != false
                sourceNotificationId = intent?.getIntExtra(EXTRA_NOTIFICATION_ID, 0) ?: 0
                hardwareSilenceEnabled = silenceOnHardware
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
                isActive = true
                if (silenceOnHardware) startHardwareWatchers()
                showOverlayIfAllowed(title)
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
        isActive = false
        instance = null
        handler.removeCallbacksAndMessages(null)
        stopHardwareWatchers()
        hideOverlay()
        releasePlayer()
        cancelSourceNotification()
        super.onDestroy()
    }

    /**
     * The optional floating card shown when the phone is unlocked or another
     * app is in front and the user granted "display over other apps".  It is
     * skipped entirely when the permission is absent or this activity is in
     * front; the full-screen player already has a stop button.
     */
    private fun showOverlayIfAllowed(title: String) {
        if (MainActivity.isForeground) return
        if (!Settings.canDrawOverlays(this)) return
        if (overlayView != null) return
        try {
            val density = resources.displayMetrics.density
            val card = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(
                    (16 * density).toInt(),
                    (10 * density).toInt(),
                    (8 * density).toInt(),
                    (10 * density).toInt(),
                )
                background = GradientDrawable().apply {
                    cornerRadius = 20 * density
                    setColor(0xF21E293B.toInt())
                    setStroke((1 * density).toInt(), 0x66FFFFFF)
                }
            }
            val label = TextView(this).apply {
                text = "$title — الأذان شغال"
                setTextColor(Color.WHITE)
                textSize = 13f
                maxLines = 1
                ellipsize = TextUtils.TruncateAt.END
                setPadding(0, 0, (8 * density).toInt(), 0)
            }
            card.addView(
                label,
                LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f),
            )
            val stop = Button(this).apply {
                text = getString(R.string.adhan_stop)
                setOnClickListener { stopSelf() }
            }
            card.addView(stop)

            val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            val params = WindowManager.LayoutParams(
                (300 * density).toInt(),
                WindowManager.LayoutParams.WRAP_CONTENT,
                type,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                y = (52 * density).toInt()
            }
            val manager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            manager.addView(card, params)
            overlayView = card
        } catch (_: Exception) {
            // The permission can be revoked between the check and addView.
            overlayView = null
        }
    }

    private fun hideOverlay() {
        val view = overlayView ?: return
        overlayView = null
        try {
            val manager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            manager.removeView(view)
        } catch (_: Exception) {
            // Already removed.
        }
    }

    /** The system ringer is silent or on vibrate: vibrate instead of sound. */
    private fun ringerIsSilent(): Boolean {
        return try {
            val manager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            manager.ringerMode != AudioManager.RINGER_MODE_NORMAL
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Screen-off and alarm-volume watchers.  They run only while the user has
     * the hardware-silencing setting on.  A volume-key press is handled by
     * [MainActivity], because the key events never reach a service.
     */
    private fun startHardwareWatchers() {
        if (screenReceiver == null) {
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == Intent.ACTION_SCREEN_OFF) stopSelf()
                }
            }
            val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                registerReceiver(receiver, filter)
            }
            screenReceiver = receiver
        }
        if (volumeObserver == null) {
            lastAlarmVolume = alarmVolume()
            val observer = object : ContentObserver(handler) {
                override fun onChange(selfChange: Boolean) {
                    val now = alarmVolume()
                    val changed = now != lastAlarmVolume
                    lastAlarmVolume = now
                    // Only another app's volume change should silence us; the
                    // user pressing the keys on our own screen is handled by
                    // the activity and would otherwise fire twice.
                    if (changed && !MainActivity.isForeground) stopSelf()
                }
            }
            contentResolver.registerContentObserver(
                Settings.System.CONTENT_URI,
                true,
                observer,
            )
            volumeObserver = observer
        }
    }

    private fun stopHardwareWatchers() {
        screenReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
                // Already unregistered.
            }
        }
        screenReceiver = null
        volumeObserver?.let {
            try {
                contentResolver.unregisterContentObserver(it)
            } catch (_: IllegalArgumentException) {
                // Already unregistered.
            }
        }
        volumeObserver = null
    }

    private fun alarmVolume(): Int {
        return try {
            val manager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            manager.getStreamVolume(AudioManager.STREAM_ALARM)
        } catch (_: Exception) {
            -1
        }
    }

    private fun cancelSourceNotification() {
        if (sourceNotificationId == 0) return
        try {
            val manager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(sourceNotificationId)
        } catch (_: Exception) {
            // Nothing to cancel.
        }
        sourceNotificationId = 0
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
        if (ringerIsSilent()) {
            // The device is silent or on vibrate: keep the full-screen player
            // and the stop action, but only vibrate.
            vibrateAdhan()
            return
        }
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
        if (fadeIn) {
            fadeStep = 0
            try {
                created.setVolume(0f, 0f)
            } catch (_: IllegalStateException) {
                // The player is not ready; start at full volume instead.
            }
        }
        try {
            created.start()
        } catch (e: Exception) {
            stopSelf()
            return
        }
        if (fadeIn) handler.postDelayed(fadeRunnable, FADE_STEP_MS)
        handler.postDelayed({
            if (player === created) stopSelf()
        }, MAX_PLAY_MS)
    }

    private fun vibrateAdhan() {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val manager =
                    getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                manager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            if (!vibrator.hasVibrator()) return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(
                    VibrationEffect.createWaveform(VIBRATION_PATTERN, -1),
                )
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(VIBRATION_PATTERN, -1)
            }
        } catch (_: Exception) {
            // Vibration is best-effort.
        }
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
        const val EXTRA_NOTIFICATION_ID = "notificationId"
        const val EXTRA_FADE_IN = "fadeIn"
        const val EXTRA_SILENCE_ON_HARDWARE = "silenceOnHardware"

        private const val CHANNEL_ID = "zaker_adhan_playback"
        private const val NOTIFICATION_ID = 7001
        private const val ASSET_PREFIX = "assets/"

        /** Longest single playback; the bundled recordings are < 4 minutes. */
        private const val MAX_PLAY_MS = 8 * 60 * 1000L

        /** Fajr's gentle fade: 20 steps of 200 ms, about four seconds. */
        private const val FADE_STEPS = 20
        private const val FADE_STEP_MS = 200L

        /** Vibrate-wait-vibrate when the ringer is silent. */
        private val VIBRATION_PATTERN =
            longArrayOf(0, 700, 250, 700, 250, 900)

        /** True while an adhan is playing; read by [MainActivity]. */
        @Volatile
        var isActive: Boolean = false
            private set

        /** The running service, for the activity to hide the floating card. */
        @Volatile
        private var instance: AdhanPlaybackService? = null

        /** Hides the optional floating card once our own screen is in front. */
        fun hideFloatingCard() {
            instance?.hideOverlay()
        }

        /** Whether the volume keys may silence the current playback. */
        @Volatile
        var hardwareSilenceEnabled: Boolean = true
            private set

        /** Starts (or restarts) the playback service. */
        fun start(
            context: Context,
            resource: String?,
            asset: String?,
            title: String,
            notificationId: Int = 0,
            fadeIn: Boolean = false,
            silenceOnHardware: Boolean = true,
        ) {
            hardwareSilenceEnabled = silenceOnHardware
            val intent = Intent(context, AdhanPlaybackService::class.java)
                .setAction(ACTION_START)
                .putExtra(EXTRA_RESOURCE, resource)
                .putExtra(EXTRA_ASSET, asset)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_NOTIFICATION_ID, notificationId)
                .putExtra(EXTRA_FADE_IN, fadeIn)
                .putExtra(EXTRA_SILENCE_ON_HARDWARE, silenceOnHardware)
            ContextCompat.startForegroundService(context, intent)
        }

        /** Stops playback and removes the ongoing notification. */
        fun stop(context: Context) {
            context.stopService(Intent(context, AdhanPlaybackService::class.java))
        }
    }
}
