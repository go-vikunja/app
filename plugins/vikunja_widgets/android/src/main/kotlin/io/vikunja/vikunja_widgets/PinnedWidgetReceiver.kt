package io.vikunja.vikunja_widgets

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * The launcher's answer to a pin request: it names the new widget's id, which
 * gets the config the app asked for, unless the configuration flow already
 * saved one.
 */
class PinnedWidgetReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val appWidgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        val config = intent.getStringExtra(EXTRA_CONFIG)
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID || config == null) return
        val pending = goAsync()
        Thread {
            try {
                val widgets = WidgetInstances(context.applicationContext)
                savePinnedConfig(
                    save = { widgets.saveConfigIfAbsent(appWidgetId, config) },
                    redraw = { widgets.updateIds(intArrayOf(appWidgetId)) },
                )
            } finally {
                finishOrSkip(pending::finish)
            }
        }.start()
    }

    companion object {
        const val EXTRA_CONFIG = "io.vikunja.vikunja_widgets.CONFIG"
    }
}

// Uncaught here, a full disk would end the app's process; the widget is
// placed already and shows its default.
fun savePinnedConfig(save: () -> Boolean, redraw: () -> Unit) {
    try {
        if (save()) redraw()
    } catch (error: Exception) {
        Log.w(TAG, "Could not save a pinned widget's config: ${error.javaClass.simpleName}")
    }
}

// Some OEM builds throw when the system counts the broadcast as finished
// already; Glance's own goAsync skips the same (b/257513022).
fun finishOrSkip(finish: () -> Unit) {
    try {
        finish()
    } catch (error: IllegalStateException) {
        Log.w(TAG, "Could not finish a broadcast: ${error.javaClass.simpleName}")
    }
}

private const val TAG = "VikunjaWidgets"
