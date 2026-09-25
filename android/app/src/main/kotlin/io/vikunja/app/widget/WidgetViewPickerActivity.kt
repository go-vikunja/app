package io.vikunja.app.widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import android.widget.ImageView
import android.widget.ListView
import android.widget.TextView
import androidx.core.content.edit
import androidx.core.net.toUri
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.state.updateAppWidgetState
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetPlugin
import io.vikunja.app.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Lightweight view switcher opened straight from the widget surface: a
 * grouped list of the built-in views, projects and saved filters. Picking an
 * entry writes the same per-instance preferences as the configuration
 * screen and requests an update for this widget instance only — no app
 * launch, no full configuration flow.
 */
class WidgetViewPickerActivity : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    private sealed interface PickerItem {
        data class Section(val title: String) : PickerItem
        data class Choice(
            val viewName: String,
            val projectId: Int?,
            val title: String,
        ) : PickerItem
    }

    private inner class PickerAdapter(
        context: Context,
        private val items: List<PickerItem>,
        private val isCurrent: (PickerItem.Choice) -> Boolean,
    ) : BaseAdapter() {
        private val inflater = LayoutInflater.from(context)

        override fun getCount() = items.size

        override fun getItem(position: Int) = items[position]

        override fun getItemId(position: Int) = position.toLong()

        override fun getViewTypeCount() = 2

        override fun getItemViewType(position: Int) =
            if (items[position] is PickerItem.Section) 0 else 1

        override fun areAllItemsEnabled() = false

        override fun isEnabled(position: Int) = items[position] is PickerItem.Choice

        override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
            return when (val item = items[position]) {
                is PickerItem.Section -> {
                    val view = convertView ?: inflater.inflate(
                        R.layout.widget_view_picker_section, parent, false
                    )
                    view.findViewById<TextView>(R.id.section_title).text = item.title
                    view
                }
                is PickerItem.Choice -> {
                    val view = convertView ?: inflater.inflate(
                        R.layout.widget_view_picker_row, parent, false
                    )
                    view.findViewById<TextView>(R.id.choice_title).text = item.title
                    view.findViewById<ImageView>(R.id.choice_check).visibility =
                        if (isCurrent(item)) View.VISIBLE else View.INVISIBLE
                    view
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.widget_view_picker)

        val prefs = HomeWidgetPlugin.getData(this)
        val currentView = prefs.getString("widget_view_$appWidgetId", "today") ?: "today"
        val currentProjectId =
            prefs.getString("widget_project_id_$appWidgetId", "0")?.toIntOrNull() ?: 0

        fun isCurrent(choice: PickerItem.Choice): Boolean = when (choice.projectId) {
            null -> currentView == choice.viewName
            else -> currentView == "project" && currentProjectId == choice.projectId
        }

        val listView = findViewById<ListView>(R.id.view_list)
        listView.adapter = PickerAdapter(this, buildItems(readProjects(prefs)), ::isCurrent)
        listView.setOnItemClickListener { _, _, position, _ ->
            val item = listView.adapter.getItem(position)
            if (item is PickerItem.Choice) {
                applyChoice(item)
            }
        }
    }

    private fun readProjects(prefs: android.content.SharedPreferences): List<WidgetProject> {
        val projectsJson = prefs.getString("WidgetProjects", null) ?: return emptyList()
        return try {
            val type = object : TypeToken<List<WidgetProject>>() {}.type
            Gson().fromJson<List<WidgetProject>>(projectsJson, type)
                ?.filterIsInstance<WidgetProject>() ?: emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun buildItems(projects: List<WidgetProject>): List<PickerItem> {
        val items = mutableListOf(
            PickerItem.Section("Views"),
            PickerItem.Choice("inbox", null, "Inbox"),
            PickerItem.Choice("today", null, "Today"),
            PickerItem.Choice("upcoming", null, "Upcoming"),
        )

        val realProjects = projects.filter { it.id > 0 }
        val savedFilters = projects.filter { it.id < 0 }
        if (realProjects.isNotEmpty()) {
            items.add(PickerItem.Section("Projects"))
            realProjects.forEach {
                items.add(PickerItem.Choice("project", it.id, it.title))
            }
        }
        if (savedFilters.isNotEmpty()) {
            items.add(PickerItem.Section("Saved filters"))
            savedFilters.forEach {
                items.add(PickerItem.Choice("project", it.id, it.title))
            }
        }
        return items
    }

    private fun applyChoice(choice: PickerItem.Choice) {
        val prefs = HomeWidgetPlugin.getData(this)
        prefs.edit {
            putString("widget_view_$appWidgetId", choice.viewName)
            // Optimistic re-render: publish the new view's title and a
            // loading state right away so the switch is visible immediately,
            // instead of showing the previous view's list until the
            // background fetch lands.
            putString("widget_title_$appWidgetId", choice.title)
            putString("widget_state_$appWidgetId", "loading")
            remove("WidgetTasks_$appWidgetId")

            if (choice.projectId != null) {
                putString("widget_project_id_$appWidgetId", choice.projectId.toString())
                putString("widget_project_name_$appWidgetId", choice.title)
            } else {
                remove("widget_project_id_$appWidgetId")
                remove("widget_project_name_$appWidgetId")
            }

            val widgetIdsJson = prefs.getString("WidgetIds", "[]") ?: "[]"
            val listType = object : TypeToken<MutableList<String>>() {}.type
            val widgetIds: MutableList<String> =
                Gson().fromJson(widgetIdsJson, listType) ?: mutableListOf()
            if (!widgetIds.contains(appWidgetId.toString())) {
                widgetIds.add(appWidgetId.toString())
            }
            putString("WidgetIds", Gson().toJson(widgetIds))
            commit()
        }

        // Recompose this instance right away so the optimistic title/loading
        // state shows without waiting for the background isolate.
        CoroutineScope(SupervisorJob() + Dispatchers.Main).launch {
            recomposeWidgetInstance(this@WidgetViewPickerActivity, appWidgetId)
        }

        val uri = "vikunja-app://updatewidget?widgetId=$appWidgetId".toUri()
        HomeWidgetBackgroundIntent.getBroadcast(this, uri).send()
        finish()
    }
}
