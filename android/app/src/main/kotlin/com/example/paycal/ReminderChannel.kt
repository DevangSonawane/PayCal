package com.devangsonawane.paycal

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

/**
 * The channel the reminders are shown in.
 *
 * Firebase falls back to a channel with the lowest importance when the
 * message names a channel that does not exist yet, so a reminder would
 * arrive without ever being shown. The backend names this channel in the
 * message it sends.
 */
object ReminderChannel {
    const val ID = "paycal_reminders"

    fun create(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            ID,
            "PayCal reminders",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Reminders and updates about the cribs you share."
        }
        val manager = context.getSystemService(NotificationManager::class.java)
        manager?.createNotificationChannel(channel)
    }
}
