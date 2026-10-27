package dev.coderoftime.vikunja.widgets

internal data class ListWidgetState(
    val appWidgetId: Int,
    val configured: Boolean,
    val key: String?,
    val accountId: String?,
    val snapshot: Snapshot?,
    val hiddenTaskIds: Set<Long>,
    val dynamicColor: Boolean,
    val linkKey: String? = null,
) {
    companion object {
        fun load(files: WidgetFiles, appWidgetId: Int): ListWidgetState {
            val config = files.readConfig(appWidgetId)
            val host = files.readHost()
            val key = if (config != null) config.key else files.defaultListKey(host)
            val snapshot = key?.let(files::readSnapshot)
            return ListWidgetState(
                appWidgetId = appWidgetId,
                configured = config != null,
                key = key,
                accountId = snapshot?.accountId ?: config?.accountId ?: host?.activeAccountId,
                snapshot = snapshot,
                hiddenTaskIds = snapshot
                    ?.let { WidgetActionQueue(files).hiddenTaskIds(it.accountId, it.generatedAt) }
                    .orEmpty(),
                dynamicColor = host?.dynamicColor ?: true,
                linkKey = host?.linkKey,
            )
        }
    }
}

// Without a config, Quick add opens the New task sheet of whichever account
// is active when tapped.
internal data class QuickAddState(
    val accountId: String?,
    val snapshot: Snapshot?,
    val dynamicColor: Boolean,
    val linkKey: String? = null,
) {
    companion object {
        fun load(files: WidgetFiles, appWidgetId: Int): QuickAddState {
            val config = files.readConfig(appWidgetId)
            val host = files.readHost()
            return QuickAddState(
                accountId = config?.accountId,
                snapshot = config?.key?.let(files::readSnapshot),
                dynamicColor = host?.dynamicColor ?: true,
                linkKey = host?.linkKey,
            )
        }
    }
}

internal data class ShownRow(val row: SnapshotRow, val tone: DueTone)

internal sealed interface ListContent {
    data class SetUp(val appWidgetId: Int, val linkKey: String? = null) : ListContent

    data class NotLoaded(val accountId: String?, val linkKey: String? = null) : ListContent

    data class Shown(
        val accountId: String,
        val title: String,
        val subtitle: String?,
        // False for a removed account or a list that is gone: only the
        // message is shown.
        val listed: Boolean,
        val generatedAt: Long,
        val count: Int,
        val countLabel: String?,
        val link: String?,
        val newTaskLink: String?,
        val newTaskLabel: String?,
        val message: WidgetText?,
        val messageLink: String?,
        val rows: List<ShownRow>,
        val more: Int,
        val moreLabel: String?,
        val empty: WidgetText?,
        val linkKey: String? = null,
    ) : ListContent

    companion object {
        fun of(state: ListWidgetState, now: Long): ListContent {
            val snapshot = state.snapshot
                ?: return if (!state.configured && state.accountId == null) {
                    SetUp(state.appWidgetId, state.linkKey)
                } else {
                    NotLoaded(state.accountId, state.linkKey)
                }
            val listed = snapshot.state != SnapshotState.ACCOUNT_REMOVED && snapshot.state != SnapshotState.GONE
            val rows = if (listed) snapshot.rows else emptyList()
            val visible = rows.filterNot { it.taskId in state.hiddenTaskIds }
            val hiddenCount = rows.size - visible.size
            val total = if (listed) (snapshot.total - hiddenCount).coerceAtLeast(visible.size) else 0
            return Shown(
                accountId = snapshot.accountId,
                title = snapshot.title,
                subtitle = snapshot.subtitle,
                listed = listed,
                generatedAt = snapshot.generatedAt,
                count = total,
                countLabel = snapshot.countLabel.takeIf { hiddenCount == 0 },
                link = snapshot.link,
                newTaskLink = snapshot.newTaskLink.takeIf { listed },
                newTaskLabel = snapshot.newTaskLabel,
                message = snapshot.message.takeIf { snapshot.state != SnapshotState.OK },
                // "Choose another list" leads to this widget's own setup.
                messageLink = if (!listed && state.configured) {
                    WidgetLinks.configureLink(state.appWidgetId, state.linkKey)
                } else {
                    snapshot.messageLink ?: snapshot.link
                },
                rows = visible.map { ShownRow(it, toneAt(it, now)) },
                more = total - visible.size,
                moreLabel = snapshot.moreLabel,
                empty = snapshot.empty,
                linkKey = state.linkKey,
            )
        }

        // The app writes a row due later today as "today"; once its instant
        // passes, it is overdue until the app writes the next snapshot.
        private fun toneAt(row: SnapshotRow, now: Long): DueTone =
            if (row.tone == DueTone.TODAY && row.dueAt != null && now >= row.dueAt) DueTone.OVERDUE else row.tone
    }
}

// The next instant the snapshot shows something else: a due instant turns a
// row overdue, and at validUntil the app's texts go stale.
internal fun Snapshot.nextChangeAt(now: Long): Long? = (changesAt + validUntil).filter { it > now }.minOrNull()
