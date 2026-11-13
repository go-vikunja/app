package io.vikunja.app.widgets

import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

// Done taps waiting for the Dart side. The app claims the queue by renaming
// it, so every write replaces the whole file: a rename racing a tap can
// leave an entry in both files, which the app drops by its id, but never
// loses one, as an append into a file already claimed and read could.
internal class WidgetActionQueue(private val files: WidgetFiles) {
    // False for a row already hidden in the snapshot it was tapped on: the
    // launcher's checkbox stays tappable until the redraw, and a second Done
    // would move a repeating task twice.
    fun add(action: WidgetAction, snapshotGeneratedAt: Long): Boolean = synchronized(lock) {
        if (action.taskId in hiddenTaskIds(action.accountId, snapshotGeneratedAt)) return false
        val lines = files.queue.readTextOrNull().orEmpty().lines().filter { it.isNotBlank() }
        files.queue.writeAtomically((lines + action.toJson()).joinToString(separator = "\n", postfix = "\n"))
        val kept = pending().filter { action.createdAt - it.createdAt < PENDING_LIFETIME_MS }
        files.pending.writeAtomically(pendingJson(kept + action))
        true
    }

    fun hasWork(): Boolean = files.queue.length() > 0 || files.claimedQueues().isNotEmpty()

    // A tapped row stays hidden until the app has taken the tap and written
    // a snapshot after it.
    fun hiddenTaskIds(accountId: String, snapshotGeneratedAt: Long): Set<Long> {
        val waiting = (queued() + claimed()).filter { it.accountId == accountId }
        val recent = pending().filter { it.accountId == accountId && it.createdAt > snapshotGeneratedAt }
        return (waiting + recent).map { it.taskId }.toSet()
    }

    fun queued(): List<WidgetAction> = linesOf(files.queue.readTextOrNull())

    private fun claimed(): List<WidgetAction> = files.claimedQueues().flatMap { linesOf(it.readTextOrNull()) }

    private fun pending(): List<WidgetAction> {
        val text = files.pending.readTextOrNull() ?: return emptyList()
        return try {
            JSONObject(text).optJSONArray("entries").objects().mapNotNull(WidgetAction::of)
        } catch (_: JSONException) {
            emptyList()
        }
    }

    private fun linesOf(text: String?): List<WidgetAction> =
        text.orEmpty().lines().filter { it.isNotBlank() }.mapNotNull(WidgetAction::parse)

    private fun pendingJson(entries: List<WidgetAction>): String {
        val array = JSONArray()
        entries.forEach { array.put(JSONObject(it.toJson())) }
        return JSONObject().put("version", 1).put("entries", array).toString()
    }

    private companion object {
        val lock = Any()
        const val PENDING_LIFETIME_MS = 24 * 60 * 60 * 1000L
    }
}
