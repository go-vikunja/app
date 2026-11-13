package io.vikunja.app.widgets

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
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
import androidx.glance.action.Action
import androidx.glance.action.clickable
import androidx.glance.appwidget.CheckBox
import androidx.glance.appwidget.CheckboxDefaults
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.lazy.items
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import io.vikunja.app.R

class TasksWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(setOf(compact, narrow, medium, wide))

    override val stateDefinition: GlanceStateDefinition<*> = FileWidgetStateDefinition { context, appWidgetId ->
        ListWidgetState.load(WidgetFiles.of(context), appWidgetId).also { state ->
            val snapshot = state.snapshot
            if (snapshot != null) {
                WidgetSchedule.onShown(context, snapshot)
            } else {
                state.key?.let { WidgetSchedule.onMissing(context, it) }
            }
        }
    }

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val state = currentState<ListWidgetState>()
            WidgetTheme(state.dynamicColor) {
                ListWidget(ListContent.of(state, System.currentTimeMillis()))
            }
        }
    }

    internal companion object {
        val compact = DpSize(110.dp, 40.dp)
        val narrow = DpSize(110.dp, 100.dp)
        val medium = DpSize(180.dp, 100.dp)
        val wide = DpSize(260.dp, 100.dp)
    }
}

class TasksWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TasksWidget()
}

private val touchTarget = 48.dp
private const val MORE_ITEM_ID = Long.MAX_VALUE
private const val SEPARATOR = " · "

@Composable
private fun ListWidget(content: ListContent) {
    val context = LocalContext.current
    Box(
        GlanceModifier
            .fillMaxSize()
            .appWidgetBackground()
            .background(GlanceTheme.colors.widgetBackground)
            .cornerRadius(android.R.dimen.system_app_widget_background_radius)
            .padding(8.dp),
    ) {
        when (content) {
            is ListContent.SetUp ->
                Notice(
                    context.getString(R.string.widget_set_up),
                    link = WidgetLinks.configure(content.appWidgetId, content.linkKey),
                )
            is ListContent.NotLoaded ->
                Notice(
                    context.getString(R.string.widget_not_loaded),
                    link = WidgetLinks.open(content.accountId, content.linkKey),
                )
            is ListContent.Shown -> ShownList(content)
        }
    }
}

@Composable
private fun ShownList(content: ListContent.Shown) {
    val context = LocalContext.current
    val size = LocalSize.current
    val compact = size.height < TasksWidget.narrow.height
    val link = WidgetLinks.parse(content.link) ?: WidgetLinks.open(content.accountId, content.linkKey)
    val messageLink = WidgetLinks.parse(content.messageLink) ?: WidgetLinks.open(content.accountId, content.linkKey)
    val message = content.message
    Column(
        GlanceModifier.fillMaxSize(),
        verticalAlignment = if (compact) Alignment.CenterVertically else Alignment.Top,
    ) {
        if (content.listed || compact) Header(content, link)
        if (compact) return@Column
        // The rest of the height; a full-height child would reach past the
        // widget's bottom edge.
        val body = GlanceModifier.defaultWeight().fillMaxWidth()
        when {
            message != null && content.rows.isEmpty() ->
                Notice(message.title, message.body, message.action, messageLink, body)
            content.rows.isEmpty() -> {
                val empty = content.empty
                Notice(empty?.title ?: context.getString(R.string.widget_empty), empty?.body, empty?.action, link, body)
            }
            else -> {
                if (message != null) Banner(message, messageLink)
                TaskList(content, link, wide = size.width >= TasksWidget.wide.width, body)
            }
        }
    }
}

@Composable
private fun Header(content: ListContent.Shown, link: Uri) {
    val context = LocalContext.current
    val colors = GlanceTheme.colors
    Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Column(
            // No full height here: in a wrap-height row it stretches the row,
            // and the header then takes the list's height.
            modifier = GlanceModifier
                .defaultWeight()
                .clickable(open(context, link))
                .padding(horizontal = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                content.title,
                maxLines = 1,
                style = TextStyle(color = colors.onSurface, fontSize = 16.sp, fontWeight = FontWeight.Medium),
            )
            content.subtitle?.let {
                Text(it, maxLines = 1, style = TextStyle(color = colors.onSurfaceVariant, fontSize = 12.sp))
            }
        }
        if (content.listed) {
            Text(
                "${content.count}",
                modifier = GlanceModifier
                    .padding(horizontal = 8.dp)
                    .semantics {
                        contentDescription = content.countLabel
                            ?: context.resources.getQuantityString(R.plurals.widget_count, content.count, content.count)
                    },
                style = TextStyle(color = colors.primary, fontSize = 14.sp, fontWeight = FontWeight.Medium),
            )
        }
        val newTask = WidgetLinks.parse(content.newTaskLink)
        if (newTask == null) {
            // Without a width of its own the spacer squeezes the title out of
            // the row.
            MinimumHeight(GlanceModifier.width(1.dp))
        } else {
            val label = content.newTaskLabel ?: context.getString(R.string.widget_new_task)
            Box(
                modifier = GlanceModifier
                    .size(touchTarget)
                    .clickable(open(context, newTask))
                    .semantics { contentDescription = label },
                contentAlignment = Alignment.Center,
            ) {
                Image(
                    ImageProvider(R.drawable.widget_add),
                    contentDescription = null,
                    modifier = GlanceModifier.size(24.dp),
                    colorFilter = ColorFilter.tint(colors.primary),
                )
            }
        }
    }
}

@Composable
private fun TaskList(content: ListContent.Shown, link: Uri, wide: Boolean, modifier: GlanceModifier) {
    val context = LocalContext.current
    LazyColumn(modifier) {
        items(content.rows, itemId = { it.row.taskId }) { row ->
            TaskRow(row, content, wide)
        }
        if (content.more > 0) {
            item(itemId = MORE_ITEM_ID) {
                Text(
                    content.moreLabel
                        ?: context.resources.getQuantityString(R.plurals.widget_more, content.more, content.more),
                    modifier = GlanceModifier
                        .fillMaxWidth()
                        .clickable(open(context, link))
                        .padding(horizontal = 12.dp, vertical = 16.dp),
                    style = TextStyle(color = GlanceTheme.colors.primary, fontSize = 13.sp, fontWeight = FontWeight.Medium),
                )
            }
        }
    }
}

@Composable
private fun TaskRow(shown: ShownRow, content: ListContent.Shown, wide: Boolean) {
    val context = LocalContext.current
    val row = shown.row
    val accountId = content.accountId
    val colors = GlanceTheme.colors
    Row(
        modifier = GlanceModifier
            .fillMaxWidth()
            .clickable(open(context, WidgetLinks.parse(row.link) ?: WidgetLinks.open(accountId, content.linkKey)))
            .semantics { contentDescription = row.semanticsLabel },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (row.canDone) {
            CheckBox(
                checked = false,
                onCheckedChange = actionRunCallback<MarkDoneAction>(
                    MarkDoneAction.parameters(accountId, row.taskId, content.generatedAt),
                ),
                modifier = GlanceModifier.size(touchTarget).semantics { contentDescription = row.doneLabel },
                colors = if (LocalSystemPalette.current) {
                    CheckboxDefaults.colors()
                } else {
                    CheckboxDefaults.colors(checkedColor = colors.primary, uncheckedColor = colors.onSurfaceVariant)
                },
            )
        } else {
            MinimumHeight(GlanceModifier.width(12.dp))
        }
        Column(GlanceModifier.defaultWeight().padding(top = 8.dp, bottom = 8.dp, end = 8.dp)) {
            Text(row.title, maxLines = 2, style = TextStyle(color = colors.onSurface, fontSize = 14.sp))
            MetaLine(shown, wide)
        }
    }
}

@Composable
private fun MetaLine(shown: ShownRow, wide: Boolean) {
    val row = shown.row
    val colors = GlanceTheme.colors
    val project = row.projectTitle.takeIf { wide }
    val labels = listOfNotNull(
        row.dueLabel?.let { it to toneColor(shown.tone) },
        row.priorityLabel?.let { it to priorityColor(row.priorityLevel) },
    )
    if (labels.isEmpty() && project == null) return
    Row(verticalAlignment = Alignment.CenterVertically) {
        // Not by colour alone; the row's description says "overdue" already.
        if (row.dueLabel != null && shown.tone == DueTone.OVERDUE) {
            Image(
                ImageProvider(R.drawable.widget_overdue),
                contentDescription = null,
                modifier = GlanceModifier.size(12.dp),
                colorFilter = ColorFilter.tint(colors.error),
            )
            Spacer(GlanceModifier.width(2.dp))
        }
        labels.forEachIndexed { index, (text, color) ->
            if (index > 0) MetaText(SEPARATOR, colors.onSurfaceVariant)
            MetaText(text, color)
        }
        project?.let {
            if (labels.isNotEmpty()) MetaText(SEPARATOR, colors.onSurfaceVariant)
            Image(
                ImageProvider(R.drawable.widget_project),
                contentDescription = null,
                modifier = GlanceModifier.size(12.dp),
                colorFilter = ColorFilter.tint(
                    row.projectColor?.let { ColorProvider(Color(it)) } ?: colors.onSurfaceVariant,
                ),
            )
            Spacer(GlanceModifier.width(3.dp))
            MetaText(it, colors.onSurfaceVariant, GlanceModifier.defaultWeight())
        }
    }
}

// Glance has no minimum height; an empty spacer of the touch target's height
// keeps a row tappable with a single line of text.
@Composable
private fun MinimumHeight(modifier: GlanceModifier = GlanceModifier) {
    Spacer(modifier.height(touchTarget))
}

@Composable
private fun MetaText(text: String, color: ColorProvider, modifier: GlanceModifier = GlanceModifier) {
    Text(text, modifier = modifier, maxLines = 1, style = TextStyle(color = color, fontSize = 12.sp))
}

@Composable
private fun toneColor(tone: DueTone): ColorProvider = when (tone) {
    DueTone.OVERDUE -> GlanceTheme.colors.error
    DueTone.TODAY -> GlanceTheme.colors.primary
    DueTone.LATER, DueTone.NONE -> GlanceTheme.colors.onSurfaceVariant
}

// The app's PriorityFlag: error from "urgent", the amber accent for "high".
@Composable
private fun priorityColor(level: Int?): ColorProvider = when {
    level != null && level >= 4 -> GlanceTheme.colors.error
    level == 3 -> GlanceTheme.colors.tertiary
    else -> GlanceTheme.colors.onSurfaceVariant
}

@Composable
private fun Banner(message: WidgetText, link: Uri) {
    val context = LocalContext.current
    Text(
        listOfNotNull(message.title, message.action).joinToString(SEPARATOR),
        modifier = GlanceModifier
            .fillMaxWidth()
            .background(GlanceTheme.colors.errorContainer)
            .cornerRadius(8.dp)
            .clickable(open(context, link))
            .padding(horizontal = 12.dp, vertical = 16.dp),
        maxLines = 2,
        style = TextStyle(color = GlanceTheme.colors.onErrorContainer, fontSize = 12.sp),
    )
}

@Composable
private fun Notice(
    title: String,
    body: String? = null,
    action: String? = null,
    link: Uri,
    modifier: GlanceModifier = GlanceModifier.fillMaxSize(),
) {
    val context = LocalContext.current
    val colors = GlanceTheme.colors
    Column(
        modifier = modifier.clickable(open(context, link)).padding(8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            title,
            maxLines = 2,
            style = TextStyle(
                color = colors.onSurface,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
            ),
        )
        body?.let {
            Text(
                it,
                maxLines = 3,
                style = TextStyle(color = colors.onSurfaceVariant, fontSize = 12.sp, textAlign = TextAlign.Center),
            )
        }
        action?.let {
            Text(
                it,
                modifier = GlanceModifier.padding(top = 4.dp),
                maxLines = 1,
                style = TextStyle(
                    color = colors.primary,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    textAlign = TextAlign.Center,
                ),
            )
        }
    }
}

private fun open(context: Context, link: Uri): Action = actionStartActivity(WidgetLinks.intent(context, link))
