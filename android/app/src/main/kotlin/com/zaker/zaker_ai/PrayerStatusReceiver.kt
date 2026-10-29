package com.zaker.zaker_ai

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Re-targets the prayer bar. Receives one alarm per prayer boundary, plus the
 * reboot, app-update and clock/timezone broadcasts that require re-arming the
 * whole stored window.
 */
class PrayerStatusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        PrayerStatusBridge.onBroadcast(context, intent)
    }
}
