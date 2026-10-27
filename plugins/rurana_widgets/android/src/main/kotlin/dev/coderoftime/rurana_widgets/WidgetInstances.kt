package dev.coderoftime.rurana_widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONException
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.util.UUID

enum class WidgetProviderKind(val receiver: String) {
    LIST("dev.coderoftime.vikunja.widgets.TasksWidgetReceiver"),
    QUICK_ADD("dev.coderoftime.vikunja.widgets.QuickAddWidgetReceiver");

    val channelName: String
        get() = if (this == LIST) "list" else "quickAdd"

    companion object {
        fun fromName(name: String?): WidgetProviderKind? = entries.firstOrNull { it.channelName == name }
    }
}

/**
 * The placed widgets of the app's two receivers and their refresh. The
 * receivers live in the app module, so they are reached by class name and an
 * explicit ACTION_APPWIDGET_UPDATE broadcast instead of a Glance dependency.
 */
class WidgetInstances(val context: Context) {
    private val manager: AppWidgetManager
        get() = AppWidgetManager.getInstance(context)

    fun configs(): List<Map<String, Any?>> {
        val placed = placed()
        pruneConfigs(placed.values.flatMap { it.asIterable() }.toSet())
        return placed.flatMap { (kind, ids) ->
            ids.map { id ->
                mapOf(
                    "appWidgetId" to id,
                    "provider" to kind.channelName,
                    "config" to readText(configFile(id)),
                )
            }
        }
    }

    fun update(keys: Set<String>) {
        if (keys.isEmpty()) return
        val activeToday = activeAccountId()?.let { "$it.today" }
        for ((kind, ids) in placed()) {
            val showing = ids.filter { id ->
                val config = readText(configFile(id))
                if (config == null) {
                    kind == WidgetProviderKind.LIST && activeToday in keys
                } else {
                    snapshotKeyOf(config) in keys
                }
            }
            broadcast(kind, showing.toIntArray())
        }
    }

    fun updateIds(appWidgetIds: IntArray) {
        for ((kind, ids) in placed()) broadcast(kind, ids.filter { it in appWidgetIds }.toIntArray())
    }

    fun updateAll() {
        for ((kind, ids) in placed()) broadcast(kind, ids)
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
        return manager.requestPinAppWidget(component(kind), null, placed)
    }

    fun saveConfigIfAbsent(appWidgetId: Int, config: String): Boolean {
        val file = configFile(appWidgetId)
        if (file.exists()) return false
        file.parentFile?.mkdirs()
        val temp = File(file.parentFile, "${file.name}.${UUID.randomUUID()}.tmp")
        return try {
            temp.writeText(config)
            temp.renameTo(file)
        } finally {
            temp.delete()
        }
    }

    private fun placed(): Map<WidgetProviderKind, IntArray> =
        WidgetProviderKind.entries.associateWith { manager.getAppWidgetIds(component(it)) }

    private fun pruneConfigs(placedIds: Set<Int>) {
        val files = File(widgetsDir(context), "configs").listFiles() ?: return
        for (file in files) {
            if (!file.name.endsWith(".json")) continue
            val id = file.name.removeSuffix(".json").toIntOrNull() ?: continue
            if (id !in placedIds) file.delete()
        }
    }

    private fun broadcast(kind: WidgetProviderKind, ids: IntArray) {
        if (ids.isEmpty()) return
        context.sendBroadcast(
            Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                .setComponent(component(kind))
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids),
        )
    }

    private fun activeAccountId(): String? =
        readText(File(widgetsDir(context), "host.json"))?.let { stringField(it, "activeAccountId") }

    private fun snapshotKeyOf(config: String): String? = stringField(config, "key")

    private fun component(kind: WidgetProviderKind) = ComponentName(context, kind.receiver)

    private fun configFile(appWidgetId: Int) = File(widgetsDir(context), "configs/$appWidgetId.json")

    companion object {
        fun widgetsDir(context: Context) = File(context.filesDir, "widgets")

        private fun readText(file: File): String? = try {
            file.readText()
        } catch (_: IOException) {
            null
        }

        // Not optString: it turns a JSON null into "null".
        private fun stringField(json: String, name: String): String? = try {
            JSONObject(json).opt(name) as? String
        } catch (_: JSONException) {
            null
        }
    }
}
