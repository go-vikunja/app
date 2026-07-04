package io.vikunja.app.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import androidx.core.net.toUri
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import es.antonborri.home_widget.HomeWidgetPlugin

class AppWidgetReciever : HomeWidgetGlanceWidgetReceiver<AppWidget>() {
    override val glanceAppWidget = AppWidget()

    // Populate WidgetIds for new widgets.
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)

        val prefs = HomeWidgetPlugin.getData(context)
        val widgetIds = readWidgetIds(prefs)
        val newlySeen = appWidgetIds.map { it.toString() }.filterNot(widgetIds::contains)
        if (newlySeen.isEmpty()) return

        widgetIds.addAll(newlySeen)
        prefs.edit().putString("WidgetIds", Gson().toJson(widgetIds)).apply()

        HomeWidgetBackgroundIntent.getBroadcast(context, "vikunja-app://updatewidget".toUri()).send()
    }

    // Ensures all inactive widgets are deleted.
    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)

        val prefs = HomeWidgetPlugin.getData(context)
        val widgetIds = readWidgetIds(prefs)
        val deletedIds = appWidgetIds.map { it.toString() }
        if (!widgetIds.removeAll(deletedIds.toSet())) return

        val editor = prefs.edit().putString("WidgetIds", Gson().toJson(widgetIds))
        deletedIds.forEach { id ->
            editor.remove("WidgetTasks_$id")
            editor.remove("widget_view_$id")
            editor.remove("widget_title_$id")
            editor.remove("widget_project_id_$id")
            editor.remove("widget_project_name_$id")
        }
        editor.apply()
    }

    private fun readWidgetIds(prefs: SharedPreferences): MutableList<String> {
        val widgetIdsJson = prefs.getString("WidgetIds", "[]") ?: "[]"
        val listType = object : TypeToken<MutableList<String>>() {}.type
        return Gson().fromJson(widgetIdsJson, listType) ?: mutableListOf()
    }
}
