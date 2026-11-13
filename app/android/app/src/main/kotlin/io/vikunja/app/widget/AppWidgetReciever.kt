package io.vikunja.app.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import io.vikunja.app.widgets.TasksWidget

// The previous official app's widget provider, kept under its class name so
// that the widgets placed with it survive the update and lead to this app's
// setup.
class AppWidgetReciever : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TasksWidget()

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        LegacyWidgets.disableIfUnused(context)
    }
}

internal object LegacyWidgets {
    const val RECEIVER = "io.vikunja.app.widget.AppWidgetReciever"

    private const val TAG = "VikunjaWidgets"

    fun isLegacy(context: Context, appWidgetId: Int): Boolean =
        AppWidgetManager.getInstance(context).getAppWidgetInfo(appWidgetId)?.provider?.className == RECEIVER

    // Not every launcher honours hide_from_picker; while enabled, the
    // provider would list the Tasks widget a second time.
    fun disableIfUnused(context: Context) {
        try {
            val component = ComponentName(context, RECEIVER)
            if (AppWidgetManager.getInstance(context).getAppWidgetIds(component).isNotEmpty()) return
            context.packageManager.setComponentEnabledSetting(
                component,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        } catch (error: RuntimeException) {
            Log.w(TAG, "Could not disable the previous app's widget provider: ${error.javaClass.simpleName}")
        }
    }
}
