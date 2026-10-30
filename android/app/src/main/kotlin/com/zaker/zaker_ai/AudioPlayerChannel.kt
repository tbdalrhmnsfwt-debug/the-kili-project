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
 * Plays private batch audio files through `MediaPlayer`, one player per client.
 *
 * A client is one Dart surface — the chat voice sheet, the resource player,
 * the bag's player — and every call names it. Previously the channel kept a
 * single `MediaPlayer`: opening a second file released the first screen's
 * player, that screen's UI still showed it playing, and its later close
 * released the new player instead. Now two screens can hold two files, and
 * closing one releases only its own.
 *
 * The channel reports real positions and durations only. When the file cannot
 * be opened or the platform has no duration for it, Dart sees an error or a
 * null duration and shows the resource as unplayable/preparing rather than a
 * made-up total. Audio focus is requested for speech, and a headphone unplug
 * pauses playback instead of continuing through the speaker.
 */
class AudioPlayerChannel(messenger: BinaryMessenger) {

    /** One client's player and its last reported state. */
    private class Client(val id: String) {
        var player: MediaPlayer? = null
        var state = "idle"
        var durationMs = 0
        var pendingOpen: MethodChannel.Result? = null
        var focusRequest: AudioFocusRequest? = null

        @Suppress("DEPRECATION")
        var legacyFocusListener: AudioManager.OnAudioFocusChangeListener? = null
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private val main = Handler(Looper.getMainLooper())
    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
        .build()

    private val clients = HashMap<String, Client>()
    private var eventSink: EventChannel.EventSink? = null
    private var noisyRegistered = false

    private var appContext: Context? = null

    private val audioManager: AudioManager?
        get() = appContext?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager

    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                for (clientId in clients.keys.toList()) pauseFromSystem(clientId)
            }
        }
    }

    /** Ticks every client that is playing, so each screen gets its own position. */
    private val ticker = object : Runnable {
        override fun run() {
            var anyPlaying = false
            for ((clientId, client) in clients) {
                val current = client.player ?: continue
                if (client.state != "playing") continue
                anyPlaying = true
                emit(clientId, "playing", current.currentPosition)
            }
            if (anyPlaying) main.postDelayed(this, TICK_MS)
        }
    }

    fun register(context: Context) {
        appContext = context.applicationContext
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "open" -> open(call, result)
                "play" -> play(call, result)
                "pause" -> pause(call, result)
                "seek" -> seek(call, result)
                "stop" -> {
                    val clientId = clientIdOf(call)
                    if (clientId != null) {
                        release(clientId)
                        emit(clientId, "idle", 0)
                    }
                    result.success(null)
                }
                "dispose" -> {
                    clientIdOf(call)?.let { release(it) }
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
        for (clientId in clients.keys.toList()) release(clientId)
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

    private fun clientIdOf(call: MethodCall): String? =
        call.argument<String>("clientId")?.takeIf { it.isNotBlank() }

    private fun open(call: MethodCall, result: MethodChannel.Result) {
        val clientId = clientIdOf(call)
        if (clientId == null) {
            result.error("openFailed", null, null)
            return
        }
        val path = call.argument<String>("path")
        if (path.isNullOrBlank() || !File(path).isFile) {
            result.error("openFailed", null, null)
            return
        }
        // Re-opening replaces only this client's file.
        release(clientId)
        val client = Client(clientId)
        clients[clientId] = client
        val created = MediaPlayer()
        client.player = created
        created.setAudioAttributes(attributes)
        created.setOnPreparedListener { prepared ->
            client.durationMs = try {
                prepared.duration.coerceAtLeast(0)
            } catch (_: IllegalStateException) {
                0
            }
            client.state = "preparing"
            emit(clientId, "preparing", 0)
            val pending = client.pendingOpen
            client.pendingOpen = null
            pending?.success(if (client.durationMs > 0) client.durationMs else null)
        }
        created.setOnCompletionListener {
            client.state = "completed"
            cancelTickerIfIdle()
            emit(clientId, "completed", client.durationMs)
            abandonFocus(client)
        }
        created.setOnErrorListener { _, _, _ ->
            client.state = "failed"
            emit(clientId, "failed", 0, errorCode = "playbackFailed")
            abandonFocus(client)
            val pending = client.pendingOpen
            client.pendingOpen = null
            pending?.error("openFailed", null, null)
            true
        }
        try {
            created.setDataSource(path)
        } catch (error: Exception) {
            release(clientId)
            result.error("openFailed", null, null)
            return
        }
        client.pendingOpen = result
        try {
            created.prepareAsync()
        } catch (error: IllegalStateException) {
            client.pendingOpen = null
            release(clientId)
            result.error("openFailed", null, null)
        }
    }

    private fun play(call: MethodCall, result: MethodChannel.Result) {
        val clientId = clientIdOf(call)
        val client = clientId?.let { clients[it] }
        val current = client?.player
        if (clientId == null || client == null || current == null) {
            result.error("notReady", null, null)
            return
        }
        if (!requestFocus(client)) {
            result.error("focusDenied", null, null)
            return
        }
        try {
            current.start()
        } catch (error: IllegalStateException) {
            abandonFocus(client)
            result.error("notReady", null, null)
            return
        }
        client.state = "playing"
        emit(clientId, "playing", current.currentPosition)
        startTicker()
        result.success(null)
    }

    private fun pause(call: MethodCall, result: MethodChannel.Result) {
        val clientId = clientIdOf(call)
        val client = clientId?.let { clients[it] }
        val current = client?.player
        if (clientId == null || client == null || current == null) {
            result.success(null)
            return
        }
        try {
            if (current.isPlaying) current.pause()
        } catch (_: IllegalStateException) {
            // Already paused or released; the reported state still applies.
        }
        pauseState(clientId, client)
        result.success(null)
    }

    private fun pauseFromSystem(clientId: String) {
        val client = clients[clientId] ?: return
        val current = client.player ?: return
        try {
            if (current.isPlaying) current.pause()
        } catch (_: IllegalStateException) {
            return
        }
        pauseState(clientId, client)
    }

    private fun pauseState(clientId: String, client: Client) {
        client.state = "paused"
        emit(clientId, "paused", client.player?.currentPosition ?: 0)
        abandonFocus(client)
        cancelTickerIfIdle()
    }

    private fun seek(call: MethodCall, result: MethodChannel.Result) {
        val clientId = clientIdOf(call)
        val client = clientId?.let { clients[it] }
        val current = client?.player
        if (clientId == null || client == null || current == null) {
            result.error("notReady", null, null)
            return
        }
        val requested = (call.argument<Number>("positionMs")?.toInt() ?: 0)
            .coerceAtLeast(0)
        val target = if (client.durationMs > 0) {
            requested.coerceAtMost(client.durationMs)
        } else {
            requested
        }
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
        emit(clientId, client.state, target)
        result.success(null)
    }

    /** Releases one client's player and drops it from the map. */
    private fun release(clientId: String) {
        val client = clients.remove(clientId) ?: return
        client.pendingOpen?.error("cancelled", null, null)
        client.pendingOpen = null
        abandonFocus(client)
        val current = client.player
        client.player = null
        client.durationMs = 0
        client.state = "idle"
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
        cancelTickerIfIdle()
    }

    private fun startTicker() {
        main.removeCallbacks(ticker)
        main.postDelayed(ticker, TICK_MS)
    }

    private fun cancelTickerIfIdle() {
        if (clients.values.none { it.state == "playing" }) main.removeCallbacks(ticker)
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

    private fun focusListenerFor(client: Client) =
        AudioManager.OnAudioFocusChangeListener { change ->
            if (change == AudioManager.AUDIOFOCUS_LOSS ||
                change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT ||
                change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK
            ) {
                pauseFromSystem(client.id)
            }
        }

    @Suppress("DEPRECATION")
    private fun requestFocus(client: Client): Boolean {
        val manager = audioManager ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = client.focusRequest ?: AudioFocusRequest
                .Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener(focusListenerFor(client))
                .build()
                .also { client.focusRequest = it }
            manager.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else {
            val listener = focusListenerFor(client)
            client.legacyFocusListener = listener
            manager.requestAudioFocus(
                listener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN,
            ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
    }

    @Suppress("DEPRECATION")
    private fun abandonFocus(client: Client) {
        val manager = audioManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            client.focusRequest?.let { manager.abandonAudioFocusRequest(it) }
        } else {
            client.legacyFocusListener?.let { manager.abandonAudioFocus(it) }
        }
    }

    private fun emit(
        clientId: String,
        state: String,
        positionMs: Int,
        errorCode: String? = null,
    ) {
        val payload = HashMap<String, Any?>()
        payload["clientId"] = clientId
        payload["state"] = state
        payload["positionMs"] = positionMs
        val duration = clients[clientId]?.durationMs ?: 0
        if (duration > 0) payload["durationMs"] = duration
        if (errorCode != null) payload["error"] = errorCode
        eventSink?.success(payload)
    }

    private companion object {
        const val METHOD_CHANNEL = "zaker/audio_player"
        const val EVENT_CHANNEL = "zaker/audio_events"
        const val TICK_MS = 400L
    }
}
