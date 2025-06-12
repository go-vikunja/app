package io.vikunja.flutteringvikunja

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class VikunjaWidgetProvider : AppWidgetProvider() {
    
    companion object {
        private const val ACTION_ADD_TASK = "ACTION_ADD_TASK"
        private const val ACTION_TOGGLE_TASK = "ACTION_TOGGLE_TASK"
        private const val EXTRA_TASK_ID = "EXTRA_TASK_ID"
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        when (intent.action) {
            ACTION_ADD_TASK -> {
                // Launch add task dialog
                val launchIntent = Intent(context, MainActivity::class.java)
                launchIntent.action = "ACTION_INSERT"
                launchIntent.type = "ADD_NEW_TASK"
                launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                context.startActivity(launchIntent)
            }
            ACTION_TOGGLE_TASK -> {
                val taskId = intent.getIntExtra(EXTRA_TASK_ID, -1)
                if (taskId != -1) {
                    // Handle task toggle through Flutter
                    HomeWidgetPlugin.saveWidgetData(context, "toggle_task_id", taskId)
                    HomeWidgetPlugin.updateWidget(context)
                }
            }
        }
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        // Get widget data from HomeWidget plugin
        val widgetData = HomeWidgetPlugin.getData(context)
        val views = RemoteViews(context.packageName, R.layout.vikunja_widget)
        
        // Set up add task button
        val addTaskIntent = Intent(context, VikunjaWidgetProvider::class.java)
        addTaskIntent.action = ACTION_ADD_TASK
        val addTaskPendingIntent = PendingIntent.getBroadcast(
            context, 0, addTaskIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.add_task_button, addTaskPendingIntent)
        
        // Set up widget title
        val title = widgetData.getString("widget_title", "Vikunja Tasks")
        views.setTextViewText(R.id.widget_title, title)
        
        // Set up task list adapter
        val serviceIntent = Intent(context, VikunjaWidgetService::class.java)
        serviceIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        views.setRemoteAdapter(R.id.task_list, serviceIntent)
        
        // Set empty view
        views.setEmptyView(R.id.task_list, R.id.empty_state)
        
        // Set up task item click template
        val taskClickIntent = Intent(context, VikunjaWidgetProvider::class.java)
        taskClickIntent.action = ACTION_TOGGLE_TASK
        val taskClickPendingIntent = PendingIntent.getBroadcast(
            context, 0, taskClickIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setPendingIntentTemplate(R.id.task_list, taskClickPendingIntent)
        
        // Update the widget
        appWidgetManager.updateAppWidget(appWidgetId, views)
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.task_list)
    }
}