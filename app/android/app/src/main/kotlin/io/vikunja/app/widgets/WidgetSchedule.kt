package io.vikunja.app.widgets

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.glance.appwidget.updateAll
import kotlinx.coroutines.CancellationException
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
    private val plan = WidgetSchedulePlan()

    @Synchronized
    fun onMissing(context: Context, key: String) {
        if (plan.asksFor(key)) WidgetActionsWorker.enqueue(context, publish = true)
    }

    @Synchronized
    fun onShown(context: Context, snapshot: Snapshot, now: Long = System.currentTimeMillis()) {
        if (plan.refreshes(snapshot, now)) WidgetActionsWorker.enqueue(context, publish = true)
        val at = plan.alarmFor(snapshot, now) ?: return
        val redraw = PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, WidgetRedrawReceiver::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        context.getSystemService(AlarmManager::class.java).set(AlarmManager.RTC, at, redraw)
    }
}

internal class WidgetSchedulePlan {
    private var alarmAt = 0L
    private var refreshedUpTo = 0L
    private val requestedKeys = mutableSetOf<String>()

    // Once per key and process: an account the app no longer has would
    // never get its snapshot.
    fun asksFor(key: String): Boolean = requestedKeys.add(key)

    // An end no later than one already asked for needs nothing: that
    // publish writes every list again.
    fun refreshes(snapshot: Snapshot, now: Long): Boolean {
        if (snapshot.validUntil > now || snapshot.validUntil <= refreshedUpTo) return false
        refreshedUpTo = snapshot.validUntil
        return true
    }

    // One alarm serves every list widget; null keeps the one set, which
    // fires by this snapshot's next change.
    fun alarmFor(snapshot: Snapshot, now: Long): Long? {
        val next = snapshot.nextChangeAt(now) ?: return null
        if (alarmAt in (now + 1)..next) return null
        alarmAt = next
        return next
    }
}

class WidgetRedrawReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        CoroutineScope(Dispatchers.Default).launch {
            try {
                redrawOrSkip { TasksWidget().updateAll(context.applicationContext) }
            } finally {
                finishOrSkip(pending::finish)
            }
        }
    }
}

// Some OEM builds throw when the system counts the broadcast as finished
// already; Glance's own goAsync skips the same (b/257513022).
internal fun finishOrSkip(finish: () -> Unit) {
    try {
        finish()
    } catch (error: IllegalStateException) {
        Log.w(TAG, "Could not finish a broadcast: ${error.javaClass.simpleName}")
    }
}

// Nothing above the receiver's own scope catches, so a failure here would end
// the app's process with its open screens. updateAll throws when Glance's
// bookkeeping cannot be read or WorkManager cannot write, as on a full disk;
// the widgets keep what they show until their next update.
internal suspend fun redrawOrSkip(redraw: suspend () -> Unit) {
    try {
        redraw()
    } catch (error: CancellationException) {
        throw error
    } catch (error: Exception) {
        Log.w(TAG, "Could not redraw the widgets: ${error.javaClass.simpleName}")
    }
}

private const val TAG = "VikunjaWidgets"
