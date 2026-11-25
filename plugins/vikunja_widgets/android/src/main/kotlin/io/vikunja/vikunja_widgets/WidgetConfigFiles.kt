package io.vikunja.vikunja_widgets

import org.json.JSONException
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.util.UUID

/**
 * The widgets folder's files the plugin reads or writes, each placed widget's
 * config and the app's host.json, with no Android calls so the app's JVM tests
 * run it.
 */
class WidgetConfigFiles(private val dir: File) {
    fun read(appWidgetId: Int): String? = readText(config(appWidgetId))

    fun saveIfAbsent(appWidgetId: Int, config: String): Boolean {
        val file = config(appWidgetId)
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

    fun prune(placedIds: Set<Int>) {
        val files = File(dir, "configs").listFiles() ?: return
        for (file in files) {
            if (!file.name.endsWith(".json")) continue
            val id = file.name.removeSuffix(".json").toIntOrNull() ?: continue
            if (id !in placedIds) file.delete()
        }
    }

    // A set-up widget shows its config's list, a list widget without one the
    // active account's Today (the app's defaultSnapshotKey).
    fun redrawn(keys: Set<String>, idsOf: (String) -> IntArray): Map<String, IntArray> {
        if (keys.isEmpty()) return emptyMap()
        val activeToday = activeAccountId()?.let { "$it.today" }
        return WidgetProviderKind.entries.flatMap { kind ->
            kind.idsByReceiver(idsOf) { id ->
                val config = read(id)
                if (config == null) {
                    kind == WidgetProviderKind.LIST && activeToday in keys
                } else {
                    stringField(config, "key") in keys
                }
            }.toList()
        }.toMap()
    }

    private fun activeAccountId(): String? =
        readText(File(dir, "host.json"))?.let { stringField(it, "activeAccountId") }

    private fun config(appWidgetId: Int) = File(dir, "configs/$appWidgetId.json")

    private companion object {
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
