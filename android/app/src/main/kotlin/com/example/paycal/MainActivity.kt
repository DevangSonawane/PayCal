package com.devangsonawane.paycal

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createReminderChannel()
    }

    /**
     * The channel the reminders are shown in.
     *
     * Firebase falls back to a channel with the lowest importance when the
     * message names a channel that does not exist yet, so a reminder would
     * arrive without ever being shown. The backend names this channel in the
     * message it sends.
     */
    private fun createReminderChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "paycal_reminders",
            "PayCal reminders",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Reminders and updates about the cribs you share."
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager?.createNotificationChannel(channel)
    }
}
