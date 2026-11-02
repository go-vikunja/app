package dev.coderoftime.rurana.widgets

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import dev.coderoftime.rurana.R

class QuickAddWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(setOf(iconOnly, withLabel))

    override val stateDefinition: GlanceStateDefinition<*> = FileWidgetStateDefinition { context, appWidgetId ->
        QuickAddState.load(WidgetFiles.of(context), appWidgetId)
    }

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val state = currentState<QuickAddState>()
            WidgetTheme(state.dynamicColor) { QuickAddButton(state) }
        }
    }

    internal companion object {
        val iconOnly = DpSize(40.dp, 40.dp)
        val withLabel = DpSize(110.dp, 40.dp)
    }
}

class QuickAddWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = QuickAddWidget()
}

@Composable
private fun QuickAddButton(state: QuickAddState) {
    val context = LocalContext.current
    val colors = GlanceTheme.colors
    val snapshot = state.snapshot
    val label = snapshot?.newTaskLabel ?: context.getString(R.string.widget_new_task)
    // A snapshot without a New task link: the account can add no task, or
    // it is gone; the tap opens the app instead.
    val target = if (snapshot == null) {
        WidgetLinks.newTask(state.accountId, state.linkKey)
    } else {
        WidgetLinks.parse(snapshot.newTaskLink)
            ?: WidgetLinks.parse(snapshot.messageLink)
            ?: WidgetLinks.open(snapshot.accountId, state.linkKey)
    }
    Row(
        modifier = GlanceModifier
            .fillMaxSize()
            .appWidgetBackground()
            .background(colors.primaryContainer)
            .cornerRadius(android.R.dimen.system_app_widget_background_radius)
            .clickable(actionStartActivity(WidgetLinks.intent(context, target)))
            .semantics { contentDescription = label },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Image(
            ImageProvider(R.drawable.widget_add),
            contentDescription = null,
            modifier = GlanceModifier.size(28.dp),
            colorFilter = ColorFilter.tint(colors.onPrimaryContainer),
        )
        if (LocalSize.current.width >= QuickAddWidget.withLabel.width) {
            Spacer(GlanceModifier.width(8.dp))
            Text(
                label,
                maxLines = 1,
                style = TextStyle(color = colors.onPrimaryContainer, fontSize = 15.sp, fontWeight = FontWeight.Medium),
            )
        }
    }
}
