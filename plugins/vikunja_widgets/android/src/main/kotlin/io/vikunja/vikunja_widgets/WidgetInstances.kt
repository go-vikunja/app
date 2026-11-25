package io.vikunja.vikunja_widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import java.io.File
import java.util.UUID

// The second list receiver is the previous official app's provider: the
// widgets placed with it are list widgets.
enum class WidgetProviderKind(val receivers: List<String>) {
    LIST(listOf("io.vikunja.app.widgets.TasksWidgetReceiver", "io.vikunja.app.widget.AppWidgetReciever")),
    QUICK_ADD(listOf("io.vikunja.app.widgets.QuickAddWidgetReceiver"));

    val channelName: String
        get() = if (this == LIST) "list" else "quickAdd"

    val pinReceiver: String
        get() = receivers.first()

    // Until set up, the previous app's widgets ask for it instead of showing
    // the active account's Today.
    fun followsActiveAccount(receiver: String): Boolean = receiver == receivers.first()

    // A broadcast redraws only the ids its receiver provides, so each
    // receiver gets its own; one with none gets no broadcast.
    fun idsByReceiver(idsOf: (String) -> IntArray, include: (Int) -> Boolean = { true }): Map<String, IntArray> =
        receivers.associateWith { idsOf(it).filter(include).toIntArray() }.filterValues { it.isNotEmpty() }

    companion object {
        fun fromName(name: String?): WidgetProviderKind? = entries.firstOrNull { it.channelName == name }
    }
}

/**
 * The placed widgets of the app's receivers and their refresh. The receivers
 * live in the app module, so they are reached by class name and an explicit
 * ACTION_APPWIDGET_UPDATE broadcast instead of a Glance dependency.
 */
class WidgetInstances(val context: Context) {
    private val manager: AppWidgetManager
        get() = AppWidgetManager.getInstance(context)

    // A getter: filesDir may touch the disk, and the plugin is attached on the
    // main thread.
    private val files: WidgetConfigFiles
        get() = WidgetConfigFiles(widgetsDir(context))

    fun configs(): List<Map<String, Any?>> {
        val placed = WidgetProviderKind.entries.associateWith { placed(it) }
        files.prune(placed.values.flatMap { byReceiver -> byReceiver.values.flatMap { it.asIterable() } }.toSet())
        return placed.flatMap { (kind, byReceiver) ->
            byReceiver.flatMap { (receiver, ids) ->
                ids.map { id ->
                    mapOf(
                        "appWidgetId" to id,
                        "provider" to kind.channelName,
                        "followsActiveAccount" to kind.followsActiveAccount(receiver),
                        "config" to files.read(id),
                    )
                }
            }
        }
    }

    fun update(keys: Set<String>) {
        broadcast(files.redrawn(keys, this::idsOf))
    }

    fun updateIds(appWidgetIds: IntArray) {
        for (kind in WidgetProviderKind.entries) broadcast(placed(kind) { it in appWidgetIds })
    }

    fun updateAll() {
        for (kind in WidgetProviderKind.entries) broadcast(placed(kind))
    }

    fun canRequestPin(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && manager.isRequestPinAppWidgetSupported

    /** [config] is the config file's content for the widget once it is placed. */
    fun requestPin(kind: WidgetProviderKind?, config: String?): Boolean {
        if (kind == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        if (!manager.isRequestPinAppWidgetSupported) return false
        val placed = config?.let {
            // Mutable: the launcher adds the new widget's id to the intent.
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
            PendingIntent.getBroadcast(
                context,
                UUID.randomUUID().hashCode(),
                Intent(context, PinnedWidgetReceiver::class.java)
                    .putExtra(PinnedWidgetReceiver.EXTRA_CONFIG, it),
                flags,
            )
        }
        return manager.requestPinAppWidget(ComponentName(context, kind.pinReceiver), null, placed)
    }

    fun saveConfigIfAbsent(appWidgetId: Int, config: String): Boolean = files.saveIfAbsent(appWidgetId, config)

    private fun placed(kind: WidgetProviderKind, include: (Int) -> Boolean = { true }): Map<String, IntArray> =
        kind.idsByReceiver(this::idsOf, include)

    private fun idsOf(receiver: String): IntArray = manager.getAppWidgetIds(ComponentName(context, receiver))

    private fun broadcast(idsByReceiver: Map<String, IntArray>) {
        for ((receiver, ids) in idsByReceiver) {
            context.sendBroadcast(
                Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                    .setComponent(ComponentName(context, receiver))
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids),
            )
        }
    }

    companion object {
        fun widgetsDir(context: Context) = File(context.filesDir, "widgets")
    }
}
