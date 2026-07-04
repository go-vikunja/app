package io.vikunja.app.widget

import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.text.format.DateFormat
import android.util.Log
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.edit
import androidx.core.net.toUri
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.appwidget.CheckBox
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.components.TitleBar
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.lazy.items
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.color.ColorProvider
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.padding
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import com.google.gson.Gson
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Date
import java.util.Locale
import androidx.glance.ImageProvider
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.components.CircleIconButton
import io.vikunja.app.MainActivity
import io.vikunja.app.R
import androidx.glance.appwidget.action.ActionCallback
import io.vikunja.app.INTENT_TYPE_ADD_TASK

class InteractiveAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_INSERT
            type = INTENT_TYPE_ADD_TASK
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }
}

class ConfigureWidgetAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters,
    ) {
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(glanceId)
        val intent = Intent(context, WidgetConfigureActivity::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }
}

class AppWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Single
    private var todayTasks: MutableList<Task> = ArrayList()
    private var otherTasks: MutableList<Task> = ArrayList()

    override val stateDefinition: GlanceStateDefinition<*>
        get() = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
        provideContent {
            GlanceContent(context, currentState(), appWidgetId)
        }
    }

    // This function cannot be composable otherwise it wont run sometimes when shared prefs isn't changed
    private fun getTasks(prefs: SharedPreferences, appWidgetId: Int) {
        // These need to be cleared in case this gets run multiple times
        todayTasks.clear()
        otherTasks.clear()
        val gson = Gson()
        val tasksJson = prefs.getString("WidgetTasks_$appWidgetId", null)

        if (tasksJson != null) {
            val tasks = try {
                gson.fromJson(tasksJson, Array<Task>::class.java)
            } catch (e: Exception) {
                Log.d("Widget", "Failed to parse cached tasks for widget $appWidgetId", e)
                null
            }

            if (tasks != null && tasks.isNotEmpty()) {
                for (task in tasks) {
                    if (task.today) {
                        todayTasks.add(task)
                    } else {
                        otherTasks.add(task)
                    }
                }
            }
        } else {
            Log.d("Widget", "No tasks found for widget $appWidgetId")
        }
    }

    private fun doneTask(context: Context, prefs: SharedPreferences, taskID: String) {
        prefs.edit {
            putString("completeTask", taskID)
            commit()
        }
        val uri = "vikunja-app://completeTask".toUri()
        val taskURI = uri.buildUpon().appendQueryParameter("taskID", taskID).build()
        val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
            context, taskURI
        )
        backgroundIntent.send()
    }

    @Composable
    private fun GlanceContent(
        context: Context,
        currentState: HomeWidgetGlanceState,
        appWidgetId: Int,
    ) {
        val prefs = currentState.preferences
        getTasks(prefs, appWidgetId)

        val viewType = prefs.getString("widget_view_$appWidgetId", "today") ?: "today"
        val widgetTitle = prefs.getString("widget_title_$appWidgetId", "Vikunja") ?: "Vikunja"
        val otherSectionLabel = when (viewType) {
            "upcoming" -> "This Week:"
            "inbox", "project" -> "Tasks:"
            else -> "Overdue:"
        }

        Column(
            modifier = GlanceModifier.fillMaxHeight(), verticalAlignment = Alignment.Top
        ) {
            WidgetTitleBar(widgetTitle)
            if (todayTasks.isEmpty() and otherTasks.isEmpty()) {
                EmptyView()
            } else {
                LazyColumn(
                    modifier = GlanceModifier.fillMaxHeight().background(
                        ColorProvider(
                            Color.White, Color(0xFF1f2937)
                        )
                    ).padding(8.dp)
                ) {
                    if (todayTasks.isNotEmpty()) {
                        item {
                            Text(
                                "Today:",
                                style = TextStyle(color = ColorProvider(Color.Black, Color.White))
                            )
                        }
                        items(todayTasks.sortedBy { it.dueDate ?: Long.MAX_VALUE }) { task ->
                            RenderRow(context, task, prefs)
                        }
                    }
                    if (otherTasks.isNotEmpty()) {
                        item {
                            Text(
                                otherSectionLabel,
                                style = TextStyle(color = ColorProvider(Color.Black, Color.White))
                            )
                        }
                        items(otherTasks.sortedBy { it.dueDate ?: Long.MAX_VALUE }) { task ->
                            RenderRow(context, task, prefs, showDate = true)
                        }
                    }
                }
            }
        }
    }

    @Composable
    private fun WidgetTitleBar(title: String = "Vikunja") {
        Box(
            modifier = GlanceModifier
                .background(ColorProvider(Color(0xFF126cfd), Color(0xFF013992))),
            contentAlignment = Alignment.Center,
        ) {
            TitleBar(
                title = title,
                startIcon = ImageProvider(R.drawable.vikunja_logo),
                iconColor = null,
                actions = {
                    Box(
                        modifier = GlanceModifier.padding(end = 4.dp, top = 4.dp, bottom = 4.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        CircleIconButton(
                            enabled = true,
                            onClick = actionRunCallback<ConfigureWidgetAction>(),
                            imageProvider = ImageProvider(R.drawable.settings),
                            contentDescription = "Configure widget",
                        )
                    }
                    Box(
                        modifier = GlanceModifier.padding(end = 8.dp, top = 4.dp, bottom = 4.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        CircleIconButton(
                            enabled = true,
                            onClick = actionRunCallback<InteractiveAction>(),
                            imageProvider = ImageProvider(R.drawable.add),
                            contentDescription = "Add a Task",
                        )
                    }
                },
            )
        }
    }

    @Composable
    private fun RenderRow(
        context: Context, task: Task, prefs: SharedPreferences, showDate: Boolean = false
    ) {
        Row(
            modifier = GlanceModifier.fillMaxWidth().padding(8.dp)
                .background(ColorProvider(Color.White, Color(0xFF1f2937))),
            verticalAlignment = Alignment.CenterVertically
        ) {
            CheckBox(
                checked = false,
                onCheckedChange = { doneTask(context, prefs, task.id) },
                modifier = GlanceModifier.padding(start = 0.dp)
            )
            val taskDueDate = task.dueDateAsDate()
            if (taskDueDate != null) {
                Box(
                    modifier = GlanceModifier.padding(start = 8.dp)
                ) {
                    Text(
                        text = formatDueDate(taskDueDate, showDate), style = TextStyle(
                            fontSize = 18.sp, color = ColorProvider(Color.Black, Color.White)
                        )
                    )
                }
            }
            Box(
                modifier = GlanceModifier.padding(start = 8.dp)
            ) {
                Text(
                    text = task.title, style = TextStyle(
                        fontSize = 18.sp, color = ColorProvider(Color.Black, Color.White)
                    ), maxLines = 1
                )
            }
        }
    }

    private fun formatDueDate(dueDate: Date, showDate: Boolean): String {
        if (showDate) {
            val pattern = DateFormat.getBestDateTimePattern(Locale.getDefault(), "MM dd j:m")
            val formatter = DateTimeFormatter.ofPattern(pattern)
            return dueDate.toInstant().atZone(ZoneId.systemDefault()).toLocalDateTime().format(
                formatter
            )
        } else {
            return dueDate.toInstant().atZone(ZoneId.systemDefault()).toLocalDateTime().format(
                DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withLocale(Locale.getDefault())
            )
        }
    }

    @Composable
    private fun EmptyView() {
        Box(
            modifier = GlanceModifier.fillMaxSize()
                .background(ColorProvider(Color.White, Color(0xFF1f2937))),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "No tasks", style = TextStyle(
                    fontSize = 16.sp, color = ColorProvider(
                        Color.Black, Color.White
                    )
                )
            )
        }
    }
}
