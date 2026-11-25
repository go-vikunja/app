package io.vikunja.app.widgets

import io.vikunja.vikunja_widgets.WidgetConfigFiles
import io.vikunja.vikunja_widgets.savePinnedConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class WidgetConfigFilesTest {
    @get:Rule
    val folder = TemporaryFolder()

    private val dir by lazy { File(folder.root, "widgets") }
    private val files by lazy { WidgetConfigFiles(dir) }

    private val tasks = TasksWidgetReceiver::class.java.name
    private val quickAdd = QuickAddWidgetReceiver::class.java.name
    private val placed = mapOf(tasks to intArrayOf(1, 2, 3), quickAdd to intArrayOf(4, 5))

    @Test
    fun `a widget added from the app gets its config`() {
        var redraws = 0

        savePinnedConfig(save = { files.saveIfAbsent(7, config("acc.label_3")) }, redraw = { redraws++ })

        assertEquals(config("acc.label_3"), files.read(7))
        assertEquals(1, redraws)
        assertEquals(listOf("7.json"), configNames())
    }

    @Test
    fun `a config its setup already saved is never overwritten`() {
        write("configs/7.json", config("acc.project_5"))
        var redraws = 0

        savePinnedConfig(save = { files.saveIfAbsent(7, config("acc.label_3")) }, redraw = { redraws++ })

        assertEquals(config("acc.project_5"), files.read(7))
        assertEquals(0, redraws)
        assertEquals(listOf("7.json"), configNames())
    }

    @Test
    fun `a failed write while placing a widget is caught`() {
        folder.newFile("widgets")

        savePinnedConfig(save = { files.saveIfAbsent(7, config("acc.label_3")) }, redraw = { fail() })

        assertNull(files.read(7))
    }

    @Test
    fun `a failed redraw while placing a widget is caught`() {
        savePinnedConfig(
            save = { files.saveIfAbsent(7, config("acc.label_3")) },
            redraw = { throw IllegalStateException() },
        )

        assertEquals(config("acc.label_3"), files.read(7))
    }

    @Test
    fun `a pin answer the system counts as finished already is skipped`() {
        var finishes = 0

        io.vikunja.vikunja_widgets.finishOrSkip { finishes++ }
        io.vikunja.vikunja_widgets.finishOrSkip { throw IllegalStateException("Broadcast already finished") }

        assertEquals(1, finishes)
    }

    @Test
    fun `a redraw reaches only the widgets whose list changed`() {
        write("host.json", """{"version":1,"activeAccountId":"acc","dynamicColor":true}""")
        write("configs/1.json", config("acc.label_3"))
        write("configs/2.json", config("acc.project_5"))
        write("configs/4.json", config("acc.quick_add"))

        assertEquals(mapOf(tasks to listOf(1)), redrawn("acc.label_3"))
        assertEquals(mapOf(tasks to listOf(2), quickAdd to listOf(4)), redrawn("acc.project_5", "acc.quick_add"))
        assertEquals(mapOf(tasks to listOf(3)), redrawn("acc.today"))
        assertEquals(emptyMap<String, List<Int>>(), redrawn("other.today"))
    }

    @Test
    fun `a list widget never set up follows no account while none is active`() {
        write("host.json", """{"version":1,"activeAccountId":null,"dynamicColor":true}""")

        assertEquals(emptyMap<String, List<Int>>(), redrawn("acc.today", "null.today"))
    }

    @Test
    fun `a redraw for a label created offline reaches its widget`() {
        write("configs/1.json", config("acc.label_-3"))

        assertEquals(mapOf(tasks to listOf(1)), redrawn("acc.label_-3"))
    }

    @Test
    fun `an empty redraw asks the system for no widget`() {
        val asked = mutableListOf<String>()

        val redrawn = files.redrawn(emptySet()) { receiver ->
            asked.add(receiver)
            placed.getValue(receiver)
        }

        assertTrue(redrawn.isEmpty())
        assertTrue(asked.isEmpty())
    }

    @Test
    fun `drops only the configs of removed widgets`() {
        for (name in listOf("1.json", "2.json", "notes.txt", "x.json")) write("configs/$name", config("acc.today"))

        files.prune(setOf(1))

        assertEquals(listOf("1.json", "notes.txt", "x.json"), configNames())
    }

    private fun config(key: String) = """{"version":1,"key":"$key"}"""

    private fun write(path: String, text: String) {
        File(dir, path).apply { parentFile?.mkdirs() }.writeText(text)
    }

    private fun configNames(): List<String> = File(dir, "configs").list().orEmpty().sorted()

    private fun redrawn(vararg keys: String): Map<String, List<Int>> =
        files.redrawn(keys.toSet()) { placed[it] ?: intArrayOf() }.mapValues { it.value.toList() }
}
