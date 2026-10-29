package com.zaker.zaker_ai

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject

/**
 * The ongoing prayer notification.
 *
 * Android's own chronometer renders the countdown, so the app process does not
 * have to be alive: Dart computes the eight-day prayer window once and this
 * bridge stores it, posts the bar for the first boundary, and schedules one
 * alarm per boundary. Each alarm re-posts the bar with the following boundary
 * as its new target. The stored window is what lets a reboot, an app update or
 * a clock change re-arm everything without the UI opening.
 */
object PrayerStatusBridge {
    const val CHANNEL = "zaker/prayer_status"
    const val ACTION_BOUNDARY = "com.zaker.zaker_ai.PRAYER_STATUS_BOUNDARY"

    private const val NOTIFICATION_ID = 9000
    private const val CHANNEL_ID = "zaker_prayer_status"
    private const val PREFS = "prayer_status_prefs"
    private const val KEY_PAYLOAD = "payload"
    private const val KEY_CITY = "city"
    private const val KEY_ALARMS = "alarm_count"
    private const val ALARM_REQUEST_BASE = 9100
    private const val CONTENT_REQUEST = 9200
    private const val MAX_ALARMS = 64
    private const val BOUNDARY_GRACE_MS = 2_000L

    /** Stores [arguments], posts the bar and re-arms every boundary alarm. */
    fun sync(context: Context, arguments: Map<*, *>?): Boolean {
        val city = arguments?.get("city") as? String ?: ""
        val raw = arguments?.get("boundaries") as? List<*> ?: emptyList<Any?>()
        val now = System.currentTimeMillis()
        val boundaries = JSONArray()
        for (item in raw) {
            val map = item as? Map<*, *> ?: continue
            val at = (map["at"] as? Number)?.toLong() ?: continue
            if (at <= now) continue
            boundaries.put(
                JSONObject()
                    .put("at", at)
                    .put("name", map["name"] as? String ?: "")
                    .put("hour", (map["hour"] as? Number)?.toInt() ?: 0)
                    .put("minute", (map["minute"] as? Number)?.toInt() ?: 0),
            )
        }
        if (boundaries.length() == 0) {
            cancel(context)
            return false
        }
        val payload = JSONObject().put("city", city).put("boundaries", boundaries)
        prefs(context)
            .edit()
            .putString(KEY_PAYLOAD, payload.toString())
            .putString(KEY_CITY, city)
            .apply()
        scheduleAlarms(context, boundaries)
        post(context, boundaries.getJSONObject(0))
        return true
    }

    /** Hides the bar and forgets the window, cancelling every alarm. */
    fun cancel(context: Context) {
        prefs(context).edit().remove(KEY_PAYLOAD).remove(KEY_CITY).apply()
        cancelAlarms(context)
        notificationManager(context).cancel(NOTIFICATION_ID)
    }

    /**
     * Boundary alarms and the system broadcasts that invalidate them. A
     * boundary alarm picks the first boundary still ahead of now, with a small
     * grace window so an alarm that fires a fraction early does not re-target
     * itself; every other action simply re-arms and re-posts.
     */
    fun onBroadcast(context: Context, intent: Intent?) {
        val boundaries = readBoundaries(context)
        if (boundaries == null) {
            cancel(context)
            return
        }
        val now = System.currentTimeMillis()
        val lead = if (intent?.action == ACTION_BOUNDARY) BOUNDARY_GRACE_MS else 0L
        val index = nextIndex(boundaries, now, lead)
        if (index < 0) {
            cancel(context)
            return
        }
        scheduleAlarms(context, boundaries)
        post(context, boundaries.getJSONObject(index))
    }

    private fun post(context: Context, boundary: JSONObject) {
        ensureChannel(context)
        val city = prefs(context).getString(KEY_CITY, "") ?: ""
        val clock = clockText(boundary.getInt("hour"), boundary.getInt("minute"))
        val content = Intent(context, MainActivity::class.java)
            .putExtra("route", "/prayer")
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val contentIntent = PendingIntent.getActivity(
            context,
            CONTENT_REQUEST,
            content,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        // The lock screen shows this generic version: the city and prayer name
        // stay private until the device is unlocked.
        val publicVersion = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_adhan_notification)
            .setContentTitle("رفيق الطالب")
            .setContentText("مواقيت الصلاة")
            .build()
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_adhan_notification)
            .setContentTitle("الصلاة القادمة: ${boundary.getString("name")}")
            .setContentText("$clock • $city")
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setShowWhen(true)
            .setWhen(boundary.getLong("at"))
            .setUsesChronometer(true)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(publicVersion)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            builder.setChronometerCountDown(true)
        }
        notificationManager(context).notify(NOTIFICATION_ID, builder.build())
    }

    private fun scheduleAlarms(context: Context, boundaries: JSONArray) {
        cancelAlarms(context)
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            manager.canScheduleExactAlarms()
        val now = System.currentTimeMillis()
        val count = minOf(boundaries.length(), MAX_ALARMS)
        for (i in 0 until count) {
            val at = boundaries.getJSONObject(i).getLong("at")
            if (at <= now) continue
            val pending = alarmIntent(context, i)
            if (exact) {
                manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
            } else {
                manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
            }
        }
        prefs(context).edit().putInt(KEY_ALARMS, count).apply()
    }

    private fun cancelAlarms(context: Context) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val count = prefs(context).getInt(KEY_ALARMS, 0)
        for (i in 0 until count) {
            val pending = alarmIntent(context, i)
            manager.cancel(pending)
            pending.cancel()
        }
        prefs(context).edit().putInt(KEY_ALARMS, 0).apply()
    }

    private fun alarmIntent(context: Context, index: Int): PendingIntent {
        val intent = Intent(context, PrayerStatusReceiver::class.java)
            .setAction(ACTION_BOUNDARY)
        return PendingIntent.getBroadcast(
            context,
            ALARM_REQUEST_BASE + index,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun nextIndex(boundaries: JSONArray, now: Long, lead: Long): Int {
        for (i in 0 until boundaries.length()) {
            if (boundaries.getJSONObject(i).getLong("at") > now + lead) return i
        }
        return -1
    }

    /** «5:04 ص» — Western digits and a ص/م suffix, matching the in-app pill. */
    private fun clockText(hour: Int, minute: Int): String {
        val suffix = if (hour < 12) "ص" else "م"
        val h = if (hour % 12 == 0) 12 else hour % 12
        return "$h:${minute.toString().padStart(2, '0')} $suffix"
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "شريط مواقيت الصلاة",
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.setSound(null, null)
        channel.enableVibration(false)
        channel.setShowBadge(false)
        notificationManager(context).createNotificationChannel(channel)
    }

    private fun readBoundaries(context: Context): JSONArray? {
        val raw = prefs(context).getString(KEY_PAYLOAD, null) ?: return null
        return try {
            JSONObject(raw).optJSONArray("boundaries")
        } catch (_: Exception) {
            null
        }
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun notificationManager(context: Context) =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
}
