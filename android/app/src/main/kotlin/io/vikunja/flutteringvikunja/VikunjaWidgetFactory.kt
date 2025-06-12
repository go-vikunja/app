package io.vikunja.flutteringvikunja

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class VikunjaWidgetFactory(private val context: Context, intent: Intent) : RemoteViewsService.RemoteViewsFactory {
    
    private val appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
    private var tasks = mutableListOf<JSONObject>()
    
    override fun onCreate() {
        // Initialize the factory
    }
    
    override fun onDestroy() {
        tasks.clear()
    }
    
    override fun onDataSetChanged() {
        // Refresh the data
        val widgetData = HomeWidgetPlugin.getData(context)
        val tasksJson = widgetData.getString("tasks_json", "[]")
        
        tasks.clear()
        try {
            val jsonArray = JSONArray(tasksJson)
            for (i in 0 until jsonArray.length()) {
                tasks.add(jsonArray.getJSONObject(i))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    override fun getCount(): Int {
        return tasks.size
    }
    
    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.task_item_widget)
        
        if (position >= tasks.size) {
            return views
        }
        
        val task = tasks[position]
        
        // Set task title
        val title = task.optString("title", "Untitled Task")
        views.setTextViewText(R.id.task_title, title)
        
        // Set task done status
        val done = task.optBoolean("done", false)
        views.setBoolean(R.id.task_checkbox, "setChecked", done)
        
        // Set task due date
        val dueDate = task.optString("due_date", "")
        if (dueDate.isNotEmpty() && dueDate != "0001-01-01T00:00:00Z") {
            try {
                val date = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).parse(dueDate)
                val displayDate = SimpleDateFormat("MMM dd", Locale.US).format(date!!)
                views.setTextViewText(R.id.task_due_date, displayDate)
                views.setViewVisibility(R.id.task_due_date, android.view.View.VISIBLE)
            } catch (e: Exception) {
                views.setViewVisibility(R.id.task_due_date, android.view.View.GONE)
            }
        } else {
            views.setViewVisibility(R.id.task_due_date, android.view.View.GONE)
        }
        
        // Set task labels
        val labels = task.optJSONArray("labels")
        if (labels != null && labels.length() > 0) {
            val labelNames = mutableListOf<String>()
            for (i in 0 until labels.length()) {
                val label = labels.getJSONObject(i)
                labelNames.add(label.optString("title", ""))
            }
            views.setTextViewText(R.id.task_labels, labelNames.joinToString(", "))
            views.setViewVisibility(R.id.task_labels, android.view.View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.task_labels, android.view.View.GONE)
        }
        
        // Set task priority
        val priority = task.optInt("priority", 0)
        if (priority > 0) {
            views.setTextViewText(R.id.task_priority, "P$priority")
            views.setViewVisibility(R.id.task_priority, android.view.View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.task_priority, android.view.View.GONE)
        }
        
        // Set click intent
        val fillInIntent = Intent()
        fillInIntent.putExtra("task_id", task.optInt("id", -1))
        views.setOnClickFillInIntent(R.id.task_checkbox, fillInIntent)
        
        return views
    }
    
    override fun getLoadingView(): RemoteViews? {
        return null
    }
    
    override fun getViewTypeCount(): Int {
        return 1
    }
    
    override fun getItemId(position: Int): Long {
        if (position >= tasks.size) return position.toLong()
        return tasks[position].optLong("id", position.toLong())
    }
    
    override fun hasStableIds(): Boolean {
        return true
    }
}