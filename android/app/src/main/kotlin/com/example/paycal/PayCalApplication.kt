package com.devangsonawane.paycal

import android.app.Application

/**
 * The channel of the reminders has to exist before the first message arrives.
 *
 * A push that reaches the app while it is closed is handled by the messaging
 * service, which runs before any activity does. A channel that is only
 * created by the activity would not exist yet at that moment, and the
 * reminder would be delivered into a silent channel that never shows up.
 */
class PayCalApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        ReminderChannel.create(this)
    }
}
