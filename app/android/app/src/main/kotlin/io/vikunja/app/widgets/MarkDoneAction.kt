package io.vikunja.app.widgets

import android.content.Context
import android.util.Log
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.action.mutableActionParametersOf
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.ToggleableStateKey
import androidx.glance.appwidget.updateAll
import java.io.IOException
import java.util.UUID
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class MarkDoneAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        // A widget drawn before the Done box became a button still has a
        // checkbox until it is drawn again; unticking that is no Done.
        if (parameters[ToggleableStateKey] == false) return
        val accountId = parameters[accountKey] ?: return
        val taskId = parameters[taskKey] ?: return
        val generatedAt = parameters[generatedAtKey] ?: return
        val action = WidgetAction(
            UUID.randomUUID().toString(),
            accountId,
            taskId,
            System.currentTimeMillis(),
            shownOf(parameters),
        )
        val queued = try {
            withContext(Dispatchers.IO) { WidgetActionQueue(WidgetFiles.of(context)).add(action, generatedAt) }
        } catch (error: IOException) {
            Log.w(TAG, "Could not queue a widget Done: ${error.javaClass.simpleName}")
            false
        }
        // Before the redraw: it can fail on Glance's own state, and the queued
        // tap would then wait for the next background run.
        if (queued) WidgetActionsWorker.enqueue(context)
        // Also without a new entry: the redraw clears the tick the launcher drew.
        TasksWidget().updateAll(context)
    }

    internal companion object {
        private const val TAG = "VikunjaWidgets"
        private val accountKey = ActionParameters.Key<String>("account")
        private val taskKey = ActionParameters.Key<Long>("task")
        private val generatedAtKey = ActionParameters.Key<Long>("generatedAt")

        // A checkbox drawn before the rows said what they showed lacks it.
        private val showsRowKey = ActionParameters.Key<Boolean>("showsRow")
        private val dueAtKey = ActionParameters.Key<Long>("dueAt")

        fun parameters(accountId: String, taskId: Long, snapshotGeneratedAt: Long, dueAt: Long?): ActionParameters =
            mutableActionParametersOf(
                accountKey to accountId,
                taskKey to taskId,
                generatedAtKey to snapshotGeneratedAt,
                showsRowKey to true,
            ).apply { if (dueAt != null) set(dueAtKey, dueAt) }

        fun shownOf(parameters: ActionParameters): TappedRow? =
            if (parameters[showsRowKey] == true) TappedRow(parameters[dueAtKey]) else null
    }
}
