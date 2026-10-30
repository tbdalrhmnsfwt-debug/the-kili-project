package com.zaker.zaker_ai

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Plays one private batch audio file through `MediaPlayer`.
 *
 * The channel reports real positions and durations only. When the file cannot
 * be opened or the platform has no duration for it, Dart sees an error or a
 * null duration and shows the resource as unplayable/preparing rather than a
 * made-up total. Audio focus is requested for speech, and a headphone unplug
 * pauses playback instead of continuing through the speaker.
 */
class AudioPlayerChannel(messenger: BinaryMessenger) {

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private val main = Handler(Looper.getMainLooper())
    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
        .build()

    private var player: MediaPlayer? = null
    private var eventSink: EventChannel.EventSink? = null
    private var pendingOpen: MethodChannel.Result? = null
    private var state = "idle"
    private var durationMs = 0
    private var focusRequest: AudioFocusRequest? = null
    private var noisyRegistered = false

    private val audioManager: AudioManager?
        get() = appContext?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager

    private var appContext: Context? = null

    /** The last reported state, so ticks repeat it verbatim. */
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change == AudioManager.AUDIOFOCUS_LOSS ||
            change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT ||
            change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK
        ) {
            pauseFromSystem()
        }
    }

    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                pauseFromSystem()
            }
        }
    }

    private val ticker = object : Runnable {
        override fun run() {
            val current = player ?: return
            if (state != "playing") return
            emit("playing", current.currentPosition)
            main.postDelayed(this, TICK_MS)
        }
    }

    fun register(context: Context) {
        appContext = context.applicationContext
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "open" -> open(call, result)
                "play" -> play(result)
                "pause" -> pause(result)
                "seek" -> seek(call, result)
                "stop" -> {
                    releasePlayer()
                    emit("idle", 0)
                    result.success(null)
                }
                "dispose" -> {
                    releasePlayer()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                eventSink = sink
                registerNoisyReceiver()
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    /** Releases everything; called when the activity is destroyed. */
    fun dispose() {
        releasePlayer()
        appContext?.let { context ->
            if (noisyRegistered) {
                try {
                    context.unregisterReceiver(noisyReceiver)
                } catch (_: IllegalArgumentException) {
                    // The receiver was already unregistered.
                }
                noisyRegistered = false
            }
        }
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        appContext = null
    }

    private fun open(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path.isNullOrBlank() || !File(path).isFile) {
            result.error("openFailed", null, null)
            return
        }
        if (pendingOpen != null) {
            pendingOpen?.error("openFailed", null, null)
            pendingOpen = null
        }
        releasePlayer()
        val created = MediaPlayer()
        player = created
        created.setAudioAttributes(attributes)
        created.setOnPreparedListener { prepared ->
            durationMs = try {
                prepared.duration.coerceAtLeast(0)
            } catch (_: IllegalStateException) {
                0
            }
            state = "preparing"
            emit("preparing", 0)
            val pending = pendingOpen
            pendingOpen = null
            pending?.success(if (durationMs > 0) durationMs else null)
        }
        created.setOnCompletionListener {
            cancelTicker()
            state = "completed"
            emit("completed", durationMs)
            abandonFocus()
        }
        created.setOnErrorListener { _, _, _ ->
            cancelTicker()
            state = "failed"
            emit("failed", 0, errorCode = "playbackFailed")
            abandonFocus()
            val pending = pendingOpen
            pendingOpen = null
            pending?.error("openFailed", null, null)
            true
        }
        try {
            created.setDataSource(path)
        } catch (error: Exception) {
            releasePlayer()
            result.error("openFailed", null, null)
            return
        }
        pendingOpen = result
        try {
            created.prepareAsync()
        } catch (error: IllegalStateException) {
            pendingOpen = null
            releasePlayer()
            result.error("openFailed", null, null)
        }
    }

    private fun play(result: MethodChannel.Result) {
        val current = player
        if (current == null) {
            result.error("notReady", null, null)
            return
        }
        if (!requestFocus()) {
            result.error("focusDenied", null, null)
            return
        }
        try {
            current.start()
        } catch (error: IllegalStateException) {
            abandonFocus()
            result.error("notReady", null, null)
            return
        }
        state = "playing"
        emit("playing", current.currentPosition)
        startTicker()
        result.success(null)
    }

    private fun pause(result: MethodChannel.Result) {
        val current = player
        if (current == null) {
            result.success(null)
            return
        }
        try {
            if (current.isPlaying) current.pause()
        } catch (_: IllegalStateException) {
            // Already paused or released; the reported state still applies.
        }
        pauseState()
        result.success(null)
    }

    private fun pauseFromSystem() {
        val current = player ?: return
        try {
            if (current.isPlaying) current.pause()
        } catch (_: IllegalStateException) {
            return
        }
        pauseState()
    }

    private fun pauseState() {
        cancelTicker()
        state = "paused"
        emit("paused", player?.currentPosition ?: 0)
        abandonFocus()
    }

    private fun seek(call: MethodCall, result: MethodChannel.Result) {
        val current = player
        if (current == null) {
            result.error("notReady", null, null)
            return
        }
        val requested = (call.argument<Number>("positionMs")?.toInt() ?: 0)
            .coerceAtLeast(0)
        val target = if (durationMs > 0) requested.coerceAtMost(durationMs) else requested
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                current.seekTo(target.toLong(), MediaPlayer.SEEK_CLOSEST)
            } else {
                @Suppress("DEPRECATION")
                current.seekTo(target)
            }
        } catch (error: IllegalStateException) {
            result.error("seekFailed", null, null)
            return
        }
        emit(state, target)
        result.success(null)
    }

    private fun releasePlayer() {
        cancelTicker()
        abandonFocus()
        pendingOpen?.error("cancelled", null, null)
        pendingOpen = null
        val current = player
        player = null
        durationMs = 0
        state = "idle"
        if (current != null) {
            try {
                current.reset()
            } catch (_: IllegalStateException) {
            }
            try {
                current.release()
            } catch (_: Exception) {
            }
        }
    }

    private fun startTicker() {
        main.removeCallbacks(ticker)
        main.postDelayed(ticker, TICK_MS)
    }

    private fun cancelTicker() {
        main.removeCallbacks(ticker)
    }

    private fun registerNoisyReceiver() {
        val context = appContext ?: return
        if (noisyRegistered) return
        val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(noisyReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                context.registerReceiver(noisyReceiver, filter)
            }
            noisyRegistered = true
        } catch (_: Exception) {
            // Without the receiver playback simply does not auto-pause.
        }
    }

    private fun requestFocus(): Boolean {
        val manager = audioManager ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = focusRequest ?: AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener(focusListener)
                .build()
                .also { focusRequest = it }
            manager.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else {
            @Suppress("DEPRECATION")
            manager.requestAudioFocus(
                focusListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN,
            ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
    }

    private fun abandonFocus() {
        val manager = audioManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { manager.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            manager.abandonAudioFocus(focusListener)
        }
    }

    private fun emit(state: String, positionMs: Int, errorCode: String? = null) {
        val payload = HashMap<String, Any?>()
        payload["state"] = state
        payload["positionMs"] = positionMs
        if (durationMs > 0) payload["durationMs"] = durationMs
        if (errorCode != null) payload["error"] = errorCode
        eventSink?.success(payload)
    }

    private companion object {
        const val METHOD_CHANNEL = "zaker/audio_player"
        const val EVENT_CHANNEL = "zaker/audio_events"
        const val TICK_MS = 400L
    }
}
