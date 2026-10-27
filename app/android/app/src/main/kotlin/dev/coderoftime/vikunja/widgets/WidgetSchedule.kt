package dev.coderoftime.vikunja.widgets

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.glance.appwidget.updateAll
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

// Keeps a shown snapshot current while the app may not run: a due instant
// passing only needs a redraw (the row turns overdue), a snapshot past its
// validUntil (midnight) needs the Dart side to write it again, and so does
// a list no snapshot exists for yet (a widget just placed from the
// launcher). The alarm is inexact and does not wake the device: a widget is
// only seen with the screen on.
internal object WidgetSchedule {
    private var alarmAt = 0L
    private var refreshedUpTo = 0L
    private val requestedKeys = mutableSetOf<String>()

    // Once per key and process: an account the app no longer has would
    // never get its snapshot.
    @Synchronized
    fun onMissing(context: Context, key: String) {
        if (requestedKeys.add(key)) WidgetActionsWorker.enqueue(context, publish = true)
    }

    @Synchronized
    fun onShown(context: Context, snapshot: Snapshot, now: Long = System.currentTimeMillis()) {
        if (snapshot.validUntil <= now && snapshot.validUntil > refreshedUpTo) {
            refreshedUpTo = snapshot.validUntil
            WidgetActionsWorker.enqueue(context, publish = true)
        }
        val next = snapshot.nextChangeAt(now) ?: return
        if (alarmAt in (now + 1)..next) return
        alarmAt = next
        val redraw = PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, WidgetRedrawReceiver::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        context.getSystemService(AlarmManager::class.java).set(AlarmManager.RTC, next, redraw)
    }
}

class WidgetRedrawReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        CoroutineScope(Dispatchers.Default).launch {
            try {
                TasksWidget().updateAll(context.applicationContext)
            } finally {
                pending.finish()
            }
        }
    }
}
