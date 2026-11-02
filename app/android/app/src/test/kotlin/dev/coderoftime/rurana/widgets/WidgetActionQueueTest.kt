package dev.coderoftime.rurana.widgets

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class WidgetActionQueueTest {
    @get:Rule
    val folder = TemporaryFolder()

    private val files by lazy { WidgetFiles(folder.root) }
    private val queue by lazy { WidgetActionQueue(files) }

    @Test
    fun `adds one line per tap and keeps the earlier ones`() {
        queue.add(WidgetAction("a", "acc", 1, 10), snapshotGeneratedAt = 0)
        queue.add(WidgetAction("b", "acc", 2, 20), snapshotGeneratedAt = 0)

        assertEquals(listOf("a", "b"), queue.queued().map { it.id })
        assertEquals(2, files.queue.readLines().count { it.isNotBlank() })
        assertTrue(queue.hasWork())
    }

    @Test
    fun `starts a new queue after the app claimed the old one`() {
        queue.add(WidgetAction("a", "acc", 1, 10), snapshotGeneratedAt = 0)
        assertTrue(files.queue.renameTo(File(folder.root, "widget_actions.1.claimed")))

        queue.add(WidgetAction("b", "acc", 2, 20), snapshotGeneratedAt = 0)

        assertEquals(listOf("b"), queue.queued().map { it.id })
        assertTrue(queue.hasWork())
    }

    @Test
    fun `skips lines it cannot read`() {
        files.queue.writeText("garbage\n{\"version\":1}\n")

        queue.add(WidgetAction("a", "acc", 1, 10), snapshotGeneratedAt = 0)

        assertEquals(listOf("a"), queue.queued().map { it.id })
    }

    @Test
    fun `has no work without a queue or a claimed file`() {
        assertFalse(queue.hasWork())

        File(folder.root, "widget_actions.7.claimed").writeText("")

        assertTrue(queue.hasWork())
    }

    @Test
    fun `hides a queued or claimed tap whatever the snapshot's age`() {
        queue.add(WidgetAction("a", "acc", 1, 10), snapshotGeneratedAt = 0)
        File(folder.root, "widget_actions.3.claimed").writeText(WidgetAction("b", "acc", 2, 10).toJson() + "\n")

        assertEquals(setOf(1L, 2L), queue.hiddenTaskIds("acc", snapshotGeneratedAt = 99))
    }

    @Test
    fun `hides a taken tap only until a snapshot written after it`() {
        queue.add(WidgetAction("a", "acc", 1, 50), snapshotGeneratedAt = 0)
        files.queue.delete()

        assertEquals(setOf(1L), queue.hiddenTaskIds("acc", snapshotGeneratedAt = 40))
        assertEquals(emptySet<Long>(), queue.hiddenTaskIds("acc", snapshotGeneratedAt = 60))
    }

    @Test
    fun `hides only the account's own rows`() {
        queue.add(WidgetAction("a", "other", 1, 50), snapshotGeneratedAt = 0)

        assertEquals(emptySet<Long>(), queue.hiddenTaskIds("acc", snapshotGeneratedAt = 40))
    }

    @Test
    fun `ignores another tap on a row it hides`() {
        assertTrue(queue.add(WidgetAction("a", "acc", 1, 10), snapshotGeneratedAt = 5))
        assertFalse(queue.add(WidgetAction("b", "acc", 1, 11), snapshotGeneratedAt = 5))

        assertTrue(files.queue.renameTo(File(folder.root, "widget_actions.1.claimed")))
        assertFalse(queue.add(WidgetAction("c", "acc", 1, 12), snapshotGeneratedAt = 5))

        // Applied by the app, but the widget has not redrawn yet.
        assertTrue(File(folder.root, "widget_actions.1.claimed").delete())
        assertFalse(queue.add(WidgetAction("d", "acc", 1, 13), snapshotGeneratedAt = 5))

        assertEquals(emptyList<String>(), queue.queued().map { it.id })
    }

    @Test
    fun `takes the same task again once a newer snapshot shows it`() {
        queue.add(WidgetAction("a", "acc", 1, 10), snapshotGeneratedAt = 5)
        files.queue.delete()

        assertTrue(queue.add(WidgetAction("b", "acc", 1, 30), snapshotGeneratedAt = 20))
        assertTrue(queue.add(WidgetAction("c", "acc", 2, 31), snapshotGeneratedAt = 5))
        assertTrue(queue.add(WidgetAction("d", "other", 1, 32), snapshotGeneratedAt = 5))

        assertEquals(listOf("b", "c", "d"), queue.queued().map { it.id })
    }

    @Test
    fun `forgets taps older than a day`() {
        val day = 24 * 60 * 60 * 1000L
        queue.add(WidgetAction("old", "acc", 1, 0), snapshotGeneratedAt = 0)
        queue.add(WidgetAction("new", "acc", 2, day + 1), snapshotGeneratedAt = 0)
        files.queue.delete()

        assertEquals(setOf(2L), queue.hiddenTaskIds("acc", snapshotGeneratedAt = -1))
    }
}
