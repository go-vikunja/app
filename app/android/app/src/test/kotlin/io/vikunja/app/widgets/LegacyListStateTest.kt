package io.vikunja.app.widgets

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class LegacyListStateTest {
    @get:Rule
    val folder = TemporaryFolder()

    private val files by lazy { WidgetFiles(folder.root) }

    @Before
    fun signedIn() {
        write("widgets/host.json", """{"version":1,"activeAccountId":"acc","linkKey":"k"}""")
        write("widgets/snapshots/acc.today.json", SampleJson.snapshot())
    }

    @Test
    fun `a widget that does not follow the active account asks to be set up until configured`() {
        val state = ListWidgetState.load(files, 5, followsActiveAccount = false)

        assertEquals(ListContent.SetUp(5, "k"), ListContent.of(state, now = 0))
    }

    @Test
    fun `a widget that follows the active account shows its Today list until configured`() {
        val content = ListContent.of(ListWidgetState.load(files, 5, followsActiveAccount = true), now = 0)

        assertEquals("Today", (content as ListContent.Shown).title)
    }

    @Test
    fun `a configured widget shows its list either way`() {
        write("widgets/configs/5.json", """{"version":1,"key":"acc.label_3","account":"acc","kind":"label","id":3}""")
        write(
            "widgets/snapshots/acc.label_3.json",
            SampleJson.snapshot().replace("acc.today", "acc.label_3").replace("\"Today\"", "\"Errands\""),
        )

        for (follows in listOf(true, false)) {
            val content = ListContent.of(ListWidgetState.load(files, 5, followsActiveAccount = follows), now = 0)

            assertEquals("Errands", (content as ListContent.Shown).title)
        }
    }

    @Test
    fun `a configured widget whose list has no snapshot yet asks to open the app either way`() {
        write("widgets/configs/5.json", """{"version":1,"key":"acc.label_3","account":"acc","kind":"label","id":3}""")

        for (follows in listOf(true, false)) {
            val state = ListWidgetState.load(files, 5, followsActiveAccount = follows)

            assertEquals(ListContent.NotLoaded("acc", "k"), ListContent.of(state, now = 0))
        }
    }

    private fun write(path: String, text: String) {
        File(folder.root, path).apply { parentFile?.mkdirs() }.writeText(text)
    }
}
