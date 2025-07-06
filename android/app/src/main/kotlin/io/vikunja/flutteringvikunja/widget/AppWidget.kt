package io.vikunja.flutteringvikunja

import HomeWidgetGlanceState
import HomeWidgetGlanceStateDefinition
import android.content.Context
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


class AppWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Single

    override val stateDefinition: GlanceStateDefinition<*>?
        get() = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceContent(context, currentState())
        }
    }


    @Composable
    private fun GlanceContent(context: Context, currentState: HomeWidgetGlanceState) {
        val prefs = currentState.preferences
        val tasks: MutableList<String> = ArrayList()

        // First work out how many tasks we gotta pull down
        val numTasks = prefs.getInt("numTasks", 0)

        // Extract all the tasks and put them into that array
        for (i in 1..numTasks) {
            val task = prefs.getString(i.toString(), null)
            task?.let { tasks.add(it) }
        }


        Column {
            MyTopBar()
            LazyColumn(modifier = GlanceModifier.background(Color.White)) {
                items(tasks) { task ->
                    RenderRow(task)
                }
            }
        }
    }

    @Composable
    private fun MyTopBar() {
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
    private fun RenderRow(taskJson: String) {
        val gson = Gson()
        val task = gson.fromJson(taskJson, ArrayList::class.java) as ArrayList<String>
        Row(modifier = GlanceModifier.fillMaxWidth().padding(8.dp)) {
            CheckBox(
                checked = false,
                onCheckedChange = {},
                modifier = GlanceModifier.padding(horizontal = 8.dp)
            )
            Box(
                modifier = GlanceModifier.padding(horizontal = 8.dp)
            ) {
                Text(
                    text = task[0], style = TextStyle(
                        fontSize = 18.sp
                    )
                )
            }
            Box(
                modifier = GlanceModifier.padding(horizontal = 8.dp)
            ) {
                Text(
                    text = task[1], style = TextStyle(
                        fontSize = 18.sp
                    )
                )
            }
        }
    }
}
