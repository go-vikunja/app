package dev.coderoftime.rurana_widgets

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

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
                if (widgets.saveConfigIfAbsent(appWidgetId, config)) widgets.updateIds(intArrayOf(appWidgetId))
            } finally {
                pending.finish()
            }
        }.start()
    }

    companion object {
        const val EXTRA_CONFIG = "dev.coderoftime.rurana_widgets.CONFIG"
    }
}
