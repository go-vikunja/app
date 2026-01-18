package io.vikunja.flutteringvikunja.widget

import HomeWidgetGlanceState
import HomeWidgetGlanceStateDefinition
import android.content.Context
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
import androidx.glance.appwidget.SizeMode
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
import androidx.glance.layout.height
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


class AppWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Single
    private var todayTasks: MutableList<Task> = ArrayList()
    private var otherTasks: MutableList<Task> = ArrayList()

    override val stateDefinition: GlanceStateDefinition<*>?
        get() = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceContent(context, currentState())
        }
    }

    // This function cannot be composable otherwise it wont run sometimes when shared prefs isn't changed
    private fun getTasks(prefs: SharedPreferences) {
        // These need to be cleared in case this gets run multiple times
        todayTasks.clear()
        otherTasks.clear()
        val gson = Gson()
        val taskIDChars = prefs.getString("WidgetTaskIDs", null)

        var taskIDs: List<String> = emptyList()

        if (taskIDChars != null) {
            val noBrackets = taskIDChars.substring(1, taskIDChars.length - 1)
            taskIDs = noBrackets.split(",")

        } else {
            Log.d("Widget", "There was a problem getting the widget ids")
        }
        // For some reason if there are no tasks an array will get created with 1 empty/null entry.
        if (taskIDs.isNotEmpty() && taskIDs[0].isNotEmpty()) {
            for (taskId in taskIDs) {
                val taskJSON = prefs.getString(taskId.trim(), null)
                val task = gson.fromJson(taskJSON, Task::class.java)
                if (task.today) {
                    todayTasks.add(task)
                } else {
                    otherTasks.add(task)
                }
            }
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
            context,
            taskURI
        )
        backgroundIntent.send()
    }

    @Composable
    private fun GlanceContent(context: Context, currentState: HomeWidgetGlanceState) {
        val prefs = currentState.preferences
        getTasks(prefs)
        Column(
            modifier = GlanceModifier.fillMaxHeight(), verticalAlignment = Alignment.Top
        ) {
            WidgetTitleBar()
            if (todayTasks.isEmpty() and otherTasks.isEmpty()) {
                EmptyView()
            } else {
                LazyColumn(
                    modifier = GlanceModifier.background(
                        ColorProvider(
                            Color.White,
                            Color(0xFF1f2937)
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
                        items(todayTasks.sortedBy { it.dueDate }) { task ->
                            RenderRow(context, task, prefs)
                        }
                    }
                    if (otherTasks.isNotEmpty()) {
                        item {
                            Text(
                                "Overdue:",
                                style = TextStyle(color = ColorProvider(Color.Black, Color.White))
                            )
                        }
                        items(otherTasks.sortedBy { it.dueDate }) { task ->
                            RenderRow(context, task, prefs, showDate = true)
                        }
                    }
                }
            }
        }
    }

    @Composable
    private fun WidgetTitleBar() {
        Box(
            modifier = GlanceModifier.fillMaxWidth().height(50.dp)
                .background(ColorProvider(Color(0xFF126cfd), Color(0xFF013992))),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "Today",
                style = TextStyle(fontSize = 20.sp, color = ColorProvider(Color.White, Color.White))
            )
        }
    }

    @Composable
    private fun RenderRow(
        context: Context,
        task: Task,
        prefs: SharedPreferences,
        showDate: Boolean = false
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
            Box(
                modifier = GlanceModifier.padding(start = 8.dp)
            ) {
                Text(
                    text = formatDueDate(task.dueDate, showDate), style = TextStyle(
                        fontSize = 18.sp,
                        color = ColorProvider(Color.Black, Color.White)
                    )
                )
            }
            Box(
                modifier = GlanceModifier.padding(start = 8.dp)
            ) {
                Text(
                    text = task.title, style = TextStyle(
                        fontSize = 18.sp,
                        color = ColorProvider(Color.Black, Color.White)
                    ),
                    maxLines = 1
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
                DateTimeFormatter
                    .ofLocalizedTime(FormatStyle.SHORT)
                    .withLocale(Locale.getDefault())
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
                text = "There are no tasks due today",
                style = TextStyle(
                    fontSize = 16.sp, color = ColorProvider(
                        Color.Black,
                        Color.White
                    )
                )
            )
        }
    }
}
