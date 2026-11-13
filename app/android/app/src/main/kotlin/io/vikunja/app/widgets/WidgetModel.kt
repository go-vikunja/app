package io.vikunja.app.widgets

import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

// The JSON the app writes (app/lib/core/widgets/widget_snapshot.dart and
// the plugin's file layout). Anything unreadable parses to null, so a widget
// shows its "open the app" state instead of failing.

internal enum class SnapshotState { OK, NEEDS_REAUTH, GUEST_ENDED, ACCOUNT_REMOVED, GONE }

internal enum class DueTone { OVERDUE, TODAY, LATER, NONE }

internal data class WidgetText(val title: String, val body: String?, val action: String?)

internal data class SnapshotRow(
    val taskId: Long,
    val title: String,
    val dueLabel: String?,
    val dueAt: Long?,
    val tone: DueTone,
    val priorityLabel: String?,
    val priorityLevel: Int?,
    val projectTitle: String?,
    val projectColor: Int?,
    val canDone: Boolean,
    val semanticsLabel: String,
    val doneLabel: String,
    val link: String,
)

internal data class Snapshot(
    val key: String,
    val accountId: String,
    val state: SnapshotState,
    val title: String,
    val subtitle: String?,
    val generatedAt: Long,
    val validUntil: Long,
    val changesAt: List<Long>,
    val rows: List<SnapshotRow>,
    val total: Int,
    val moreLabel: String?,
    val countLabel: String?,
    val empty: WidgetText?,
    val message: WidgetText?,
    val messageLink: String?,
    val link: String?,
    val newTaskLink: String?,
    val newTaskLabel: String?,
) {
    companion object {
        private const val VERSION = 1

        fun parse(text: String): Snapshot? = parseOrNull {
            val json = JSONObject(text)
            if (json.long("v") != VERSION.toLong()) return@parseOrNull null
            Snapshot(
                key = json.required("key"),
                accountId = json.required("account"),
                state = stateOf(json.string("state")) ?: return@parseOrNull null,
                title = json.required("title"),
                subtitle = json.string("subtitle"),
                generatedAt = json.long("generatedAt") ?: return@parseOrNull null,
                validUntil = json.long("validUntil") ?: return@parseOrNull null,
                changesAt = json.optJSONArray("changesAt").longs(),
                rows = json.optJSONArray("rows").objects().map(::rowOf),
                total = json.long("total")?.toInt() ?: 0,
                moreLabel = json.string("moreLabel"),
                countLabel = json.string("countLabel"),
                empty = textOf(json.optJSONObject("empty")),
                message = textOf(json.optJSONObject("message")),
                messageLink = json.string("messageLink"),
                link = json.string("link"),
                newTaskLink = json.string("newTaskLink"),
                newTaskLabel = json.string("newTaskLabel"),
            )
        }

        private fun rowOf(json: JSONObject) = SnapshotRow(
            taskId = json.long("id") ?: throw JSONException("row without id"),
            title = json.required("title"),
            dueLabel = json.string("due"),
            dueAt = json.long("dueAt"),
            tone = toneOf(json.string("tone")),
            priorityLabel = json.string("priority"),
            priorityLevel = json.long("priorityLevel")?.toInt(),
            projectTitle = json.string("project"),
            projectColor = colorOf(json.string("color")),
            canDone = json.opt("canDone") == true,
            semanticsLabel = json.required("label"),
            doneLabel = json.required("doneLabel"),
            link = json.required("link"),
        )

        private fun stateOf(name: String?) = when (name) {
            "ok" -> SnapshotState.OK
            "needsReauth" -> SnapshotState.NEEDS_REAUTH
            "guestEnded" -> SnapshotState.GUEST_ENDED
            "accountRemoved" -> SnapshotState.ACCOUNT_REMOVED
            "gone" -> SnapshotState.GONE
            else -> null
        }

        private fun toneOf(name: String?) = when (name) {
            "overdue" -> DueTone.OVERDUE
            "today" -> DueTone.TODAY
            "later" -> DueTone.LATER
            else -> DueTone.NONE
        }

        private fun textOf(json: JSONObject?): WidgetText? {
            val title = json?.string("title") ?: return null
            return WidgetText(title, json.string("body"), json.string("action"))
        }

        private val colorPattern = Regex("#?[0-9a-fA-F]{6}")

        fun colorOf(hex: String?): Int? {
            if (hex == null || !colorPattern.matches(hex)) return null
            return (0xFF000000L or hex.removePrefix("#").toLong(16)).toInt()
        }
    }
}

// The plugin's config file: its "key" plus the app's WidgetConfig JSON.
internal data class InstanceConfig(val key: String?, val accountId: String?) {
    companion object {
        fun parse(text: String): InstanceConfig? = parseOrNull {
            val json = JSONObject(text)
            InstanceConfig(key = json.string("key"), accountId = json.string("account"))
        }
    }
}

internal data class HostSettings(
    val activeAccountId: String?,
    val dynamicColor: Boolean,
    val linkKey: String? = null,
) {
    companion object {
        fun parse(text: String): HostSettings? = parseOrNull {
            val json = JSONObject(text)
            HostSettings(
                json.string("activeAccountId"),
                json.opt("dynamicColor") != false,
                json.string("linkKey")?.takeIf { it.isNotEmpty() },
            )
        }
    }
}

internal data class WidgetAction(val id: String, val accountId: String, val taskId: Long, val createdAt: Long) {
    fun toJson(): String = JSONObject()
        .put("version", 1)
        .put("id", id)
        .put("accountId", accountId)
        .put("taskId", taskId)
        .put("createdAt", createdAt)
        .toString()

    companion object {
        fun parse(text: String): WidgetAction? = parseOrNull { of(JSONObject(text)) }

        fun of(json: JSONObject): WidgetAction? {
            val id = json.string("id")?.takeIf { it.isNotEmpty() } ?: return null
            val accountId = json.string("accountId")?.takeIf { it.isNotEmpty() } ?: return null
            return WidgetAction(id, accountId, json.long("taskId") ?: return null, json.long("createdAt") ?: return null)
        }
    }
}

private inline fun <T> parseOrNull(block: () -> T?): T? = try {
    block()
} catch (_: JSONException) {
    null
}

// org.json differs between Android and the JVM in how it treats JSON null
// in optString and friends; reading the raw value behaves the same on both.
internal fun JSONObject.string(name: String): String? = opt(name) as? String

internal fun JSONObject.long(name: String): Long? = when (val value = opt(name)) {
    is Int -> value.toLong()
    is Long -> value
    else -> null
}

private fun JSONObject.required(name: String): String = string(name) ?: throw JSONException("missing $name")

private fun JSONArray?.longs(): List<Long> =
    if (this == null) emptyList() else (0 until length()).mapNotNull { (opt(it) as? Number)?.toLong() }

internal fun JSONArray?.objects(): List<JSONObject> =
    if (this == null) emptyList() else (0 until length()).mapNotNull { optJSONObject(it) }
