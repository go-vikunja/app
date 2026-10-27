package dev.coderoftime.vikunja.widgets

import android.content.Context
import android.util.Log
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.ToggleableStateKey
import androidx.glance.appwidget.updateAll
import java.io.IOException
import java.util.UUID
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class MarkDoneAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        // Android 12+ runs this on every toggle of the launcher's checkbox;
        // unticking it is no Done.
        if (parameters[ToggleableStateKey] == false) return
        val accountId = parameters[accountKey] ?: return
        val taskId = parameters[taskKey] ?: return
        val generatedAt = parameters[generatedAtKey] ?: return
        val action = WidgetAction(UUID.randomUUID().toString(), accountId, taskId, System.currentTimeMillis())
        val queued = try {
            withContext(Dispatchers.IO) { WidgetActionQueue(WidgetFiles.of(context)).add(action, generatedAt) }
        } catch (error: IOException) {
            Log.w(TAG, "Could not queue a widget Done", error)
            false
        }
        // Also without a new entry: the redraw clears the tick the launcher drew.
        TasksWidget().updateAll(context)
        if (queued) WidgetActionsWorker.enqueue(context)
    }

    internal companion object {
        private const val TAG = "RuranaWidgets"
        private val accountKey = ActionParameters.Key<String>("account")
        private val taskKey = ActionParameters.Key<Long>("task")
        private val generatedAtKey = ActionParameters.Key<Long>("generatedAt")

        fun parameters(accountId: String, taskId: Long, snapshotGeneratedAt: Long): ActionParameters =
            actionParametersOf(accountKey to accountId, taskKey to taskId, generatedAtKey to snapshotGeneratedAt)
    }
}
