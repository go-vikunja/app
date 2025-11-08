package io.vikunja.flutteringvikunja.widget

import HomeWidgetGlanceState
import HomeWidgetGlanceStateDefinition
import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.appwidget.CheckBox
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.lazy.items
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.*
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.google.gson.Gson
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import android.net.Uri
import android.util.Log
import androidx.core.content.edit
import java.time.format.DateTimeFormatter
import java.time.*
import java.util.*


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

    // This function cannot be composable otherwise it wont run sometimes when shared prefs isnt changed
    private fun getTasks(prefs: SharedPreferences) {
        // These need to be cleared in case this gets run multiple times
        todayTasks.clear()
        otherTasks.clear()
        val gson = Gson()
        val taskIDChars = prefs.getString("WidgetTaskIDs", null)

        var taskIDs: List<String>  = emptyList()

        if (taskIDChars != null) {
            val noBrackets = taskIDChars.substring(1, taskIDChars.length - 1)
            taskIDs = noBrackets.split(",")

        } else {
            Log.d("Widget", "There was a problem getting the widget ids")
        }
        // For some reason if there are no tasks an array will get created with 1 empty/null entry.
        if (taskIDs.isNotEmpty() && taskIDs[0].isNotEmpty()) {
            for (taskId in taskIDs) {
                Log.d("ITEM", "a" + taskId + "a")
                Log.d("ITEM", taskId.length.toString())
                Log.d("ITEM", (taskId == null).toString())
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
        val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
            context,
            Uri.parse("appWidget://completeTask")
        )
        backgroundIntent.send()
    }

    @Composable
    private fun GlanceContent(context: Context, currentState: HomeWidgetGlanceState) {
        Log.d("Widget", "ProvideGLance")
        val prefs = currentState.preferences
        getTasks(prefs)
        Column {
            WidgetTitleBar()
            if (todayTasks.isNotEmpty() or otherTasks.isNotEmpty()) {
                LazyColumn(modifier = GlanceModifier.background(Color.White)) {
                    item{
                        Text("Today:")
                    }
                    items(todayTasks.sortedBy { it.dueDate }) { task ->
                        RenderRow(context, task, prefs, "HH:mm")
                    }
                    item{
                        Text("OverDue")
                    }
                    items(otherTasks.sortedBy { it.dueDate }) { task ->
                        RenderRow(context, task, prefs, "dd MMM HH:mm")
                    }
                }
            } else {
                Box(modifier = GlanceModifier.fillMaxSize().background(Color.White),  contentAlignment = Alignment.Center) {
                    Text(
                        text = "There are no tasks due today"
                    )
                }
            }

        }
    }

    @Composable
    private fun WidgetTitleBar() {
        Box(
            modifier = GlanceModifier.fillMaxWidth().height(50.dp).background(Color.Blue),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "Today",
                style = TextStyle(fontSize = 20.sp, color = ColorProvider(Color.White))
            )
        }
    }

    @Composable
    private fun RenderRow(context: Context, task: Task, prefs : SharedPreferences, pattern: String) {
        Row(modifier = GlanceModifier.fillMaxWidth().padding(8.dp)) {
            CheckBox(
                checked = false,
                onCheckedChange = { doneTask(context, prefs, task.id)},
                modifier = GlanceModifier.padding(horizontal = 8.dp)
            )
            Box(
                modifier = GlanceModifier.padding(horizontal = 8.dp)
            ) {
                Text(
                    text = task.dueDate.toInstant().atZone(ZoneId.systemDefault()).toLocalDateTime().format(DateTimeFormatter.ofPattern(pattern)), style = TextStyle(
                        fontSize = 18.sp
                    )
                )
            }
            Box(
                modifier = GlanceModifier.padding(horizontal = 8.dp)
            ) {
                Text(
                    text = task.title, style = TextStyle(
                        fontSize = 18.sp
                    )
                )
            }
        }
    }
}
