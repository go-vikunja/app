package io.vikunja.app.widgets

import io.vikunja.app.widget.AppWidgetReciever
import io.vikunja.vikunja_widgets.WidgetProviderKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetProviderKindTest {
    private val tasks = TasksWidgetReceiver::class.java.name
    private val legacy = AppWidgetReciever::class.java.name
    private val quickAdd = QuickAddWidgetReceiver::class.java.name

    @Test
    fun `list widgets come from this app's receiver and the previous app's`() {
        assertEquals(listOf(tasks, legacy), WidgetProviderKind.LIST.receivers)
        assertEquals(listOf(quickAdd), WidgetProviderKind.QUICK_ADD.receivers)
    }

    @Test
    fun `a pin request places this app's widgets`() {
        assertEquals(tasks, WidgetProviderKind.LIST.pinReceiver)
        assertEquals(quickAdd, WidgetProviderKind.QUICK_ADD.pinReceiver)
    }

    @Test
    fun `only the previous app's widgets do not follow the active account`() {
        assertTrue(WidgetProviderKind.LIST.followsActiveAccount(tasks))
        assertFalse(WidgetProviderKind.LIST.followsActiveAccount(legacy))
        assertTrue(WidgetProviderKind.QUICK_ADD.followsActiveAccount(quickAdd))
    }

    @Test
    fun `the channel names stay`() {
        assertEquals(WidgetProviderKind.LIST, WidgetProviderKind.fromName("list"))
        assertEquals(WidgetProviderKind.QUICK_ADD, WidgetProviderKind.fromName("quickAdd"))
        assertNull(WidgetProviderKind.fromName("other"))
        assertNull(WidgetProviderKind.fromName(null))
    }

    @Test
    fun `each receiver gets only its own ids`() {
        val placed = mapOf(tasks to intArrayOf(1, 2), legacy to intArrayOf(3), quickAdd to intArrayOf(4))

        assertEquals(
            mapOf(tasks to listOf(1, 2), legacy to listOf(3)),
            idsByReceiver(WidgetProviderKind.LIST, placed),
        )
        assertEquals(
            mapOf(legacy to listOf(3)),
            idsByReceiver(WidgetProviderKind.LIST, placed) { it == 3 || it == 4 },
        )
        assertEquals(mapOf(quickAdd to listOf(4)), idsByReceiver(WidgetProviderKind.QUICK_ADD, placed))
    }

    @Test
    fun `a receiver without ids gets no broadcast`() {
        val placed = mapOf(tasks to intArrayOf(1), legacy to intArrayOf())

        assertEquals(mapOf(tasks to listOf(1)), idsByReceiver(WidgetProviderKind.LIST, placed))
        assertTrue(idsByReceiver(WidgetProviderKind.LIST, placed) { false }.isEmpty())
    }

    private fun idsByReceiver(
        kind: WidgetProviderKind,
        placed: Map<String, IntArray>,
        include: (Int) -> Boolean = { true },
    ): Map<String, List<Int>> =
        kind.idsByReceiver({ placed[it] ?: intArrayOf() }, include).mapValues { it.value.toList() }
}
