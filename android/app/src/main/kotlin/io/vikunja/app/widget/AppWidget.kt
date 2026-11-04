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
import androidx.glance.action.actionParametersOf
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.components.CircleIconButton
import androidx.glance.appwidget.state.updateAppWidgetState
import es.antonborri.home_widget.HomeWidgetPlugin
import io.vikunja.app.MainActivity
import io.vikunja.app.R
import io.vikunja.app.INTENT_TYPE_ADD_TASK
import java.util.concurrent.ConcurrentHashMap

class CompleteTaskAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        val taskID = parameters[taskId] ?: return
        if (taskID == "null") return

        // Optimistic completion: mark the row ticked and recompose right
        // away, so the tick doesn't revert while the server round-trip and
        // the background refresh are still in flight.
        AppWidget.markCompleting(taskID)
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(glanceId)
        recomposeWidgetInstance(context, appWidgetId)

        val prefs = HomeWidgetPlugin.getData(context)
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

    companion object {
        val taskId = ActionParameters.Key<String>("task_id")
    }
}

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

class SwitchViewAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters,
    ) {
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(glanceId)
        val intent = Intent(context, WidgetViewPickerActivity::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }
}

/**
 * Refreshes one widget instance's Glance state straight from the home-widget
 * preferences and recomposes it — the same sequence home_widget's receiver
 * runs when Dart calls updateWidget, usable without waiting for the
 * background isolate.
 */
internal suspend fun recomposeWidgetInstance(context: Context, appWidgetId: Int) {
    val glanceId = GlanceAppWidgetManager(context).getGlanceIdBy(appWidgetId)
    AppWidget().apply {
        val stateDefinition = stateDefinition as HomeWidgetGlanceStateDefinition
        updateAppWidgetState<HomeWidgetGlanceState>(
            context,
            stateDefinition,
            glanceId,
        ) { currentState -> currentState }
        update(context, glanceId)
    }
}

class AppWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Single
    private var todayTasks: MutableList<Task> = ArrayList()
    private var otherTasks: MutableList<Task> = ArrayList()

    companion object {
        private const val COMPLETING_TTL_MS = 2 * 60 * 1000L

        /**
         * Task ids ticked on the widget surface whose server round-trip hasn't
         * been reflected in the cached task list yet. Process-wide on purpose:
         * the task is as good as done on every instance showing it. Rows in
         * this set render ticked and struck through immediately; entries are
         * dropped once the cached list no longer contains the task (the
         * completion landed) or when they outlive [COMPLETING_TTL_MS] (the
         * completion presumably failed — show the task as open again).
         */
        private val completingTasks = ConcurrentHashMap<String, Long>()

        fun isCompleting(taskId: String) = completingTasks.containsKey(taskId)

        fun markCompleting(taskId: String) {
            completingTasks[taskId] = System.currentTimeMillis()
        }

        /** Forgets completions that landed or expired, judged against the
         * ids currently present in one instance's cached task list. */
        private fun pruneCompletions(cachedIds: Set<String>) {
            val now = System.currentTimeMillis()
            for (taskId in completingTasks.keys.toList()) {
                val landed = taskId !in cachedIds
                val expired = now - (completingTasks[taskId] ?: 0L) > COMPLETING_TTL_MS
                if (landed || expired) completingTasks.remove(taskId)
            }
        }
    }

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
                pruneCompletions(tasks.map { it.id }.toSet())
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
        // Written by the Dart update pipeline: 'error' means the configured
        // project or saved filter is gone for good (403/404) — show an
        // explicit error instead of the stale cached list or "No tasks".
        // 'loading' is written by the view picker while the freshly chosen
        // view's tasks are being fetched.
        val isViewStateError = prefs.getString("widget_state_$appWidgetId", "ok") == "error"
        val isLoadingView = prefs.getString("widget_state_$appWidgetId", "ok") == "loading"
        val otherSectionLabel = when (viewType) {
            "upcoming" -> "This Week:"
            "inbox", "project" -> "Tasks:"
            else -> "Overdue:"
        }

        Column(
            modifier = GlanceModifier.fillMaxHeight(), verticalAlignment = Alignment.Top
        ) {
            WidgetTitleBar(widgetTitle)
            if (isViewStateError) {
                ErrorView()
            } else if (isLoadingView) {
                LoadingView()
            } else if (todayTasks.isEmpty() and otherTasks.isEmpty()) {
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
                            onClick = actionRunCallback<SwitchViewAction>(),
                            imageProvider = ImageProvider(R.drawable.expand_more),
                            contentDescription = "Switch view",
                        )
                    }
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
        // Ticked on this surface but the completion hasn't been reflected in
        // the cached list yet: keep the row visibly done instead of letting
        // the checkbox revert while the background refresh is in flight.
        val completing = isCompleting(task.id)
        Row(
            modifier = GlanceModifier.fillMaxWidth().padding(8.dp)
                .background(ColorProvider(Color.White, Color(0xFF1f2937))),
            verticalAlignment = Alignment.CenterVertically
        ) {
            CheckBox(
                checked = completing,
                onCheckedChange = actionRunCallback<CompleteTaskAction>(
                    parameters = actionParametersOf(CompleteTaskAction.taskId to task.id)
                ),
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

    @Composable
    private fun LoadingView() {
        Box(
            modifier = GlanceModifier.fillMaxSize()
                .background(ColorProvider(Color.White, Color(0xFF1f2937))),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "Loading…", style = TextStyle(
                    fontSize = 16.sp, color = ColorProvider(
                        Color.Black, Color.White
                    )
                )
            )
        }
    }

    @Composable
    private fun ErrorView() {
        Box(
            modifier = GlanceModifier.fillMaxSize()
                .background(ColorProvider(Color.White, Color(0xFF1f2937))).padding(12.dp),
            contentAlignment = Alignment.Center,
        ) {
            Column {
                Text(
                    text = "Couldn't load this view", style = TextStyle(
                        fontSize = 16.sp, color = ColorProvider(
                            Color.Black, Color.White
                        )
                    )
                )
                Text(
                    text = "It may have been deleted. Tap ⚙ to pick another.",
                    style = TextStyle(
                        fontSize = 13.sp, color = ColorProvider(
                            Color.Black, Color.White
                        )
                    ),
                    maxLines = 2,
                )
            }
        }
    }
}
