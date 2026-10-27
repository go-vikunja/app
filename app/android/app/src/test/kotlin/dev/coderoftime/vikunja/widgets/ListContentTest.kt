package dev.coderoftime.vikunja.widgets

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class ListContentTest {
    @get:Rule
    val folder = TemporaryFolder()

    private val files by lazy { WidgetFiles(folder.root) }

    @Test
    fun `asks to be set up without a config or an active account`() {
        val state = ListWidgetState.load(files, 5)

        assertEquals(ListContent.SetUp(5), ListContent.of(state, now = 0))
        assertTrue(state.dynamicColor)
    }

    @Test
    fun `shows the active account's Today list until configured`() {
        write("widgets/host.json", """{"version":1,"activeAccountId":"acc","dynamicColor":false}""")
        write("widgets/snapshots/acc.today.json", SampleJson.snapshot())

        val state = ListWidgetState.load(files, 5)

        assertFalse(state.configured)
        assertEquals("acc.today", state.snapshot?.key)
        assertFalse(state.dynamicColor)
    }

    @Test
    fun `defaults to the active account's Today key`() {
        assertEquals("acc.today", files.defaultListKey(HostSettings("acc", true)))
        assertNull(files.defaultListKey(HostSettings(null, true)))
        assertNull(files.defaultListKey(null))
    }

    @Test
    fun `asks to open the app while the configured list has no snapshot`() {
        write("widgets/configs/5.json", """{"version":1,"key":"acc.label_3","account":"acc","kind":"label","id":3}""")
        write("widgets/host.json", """{"version":1,"activeAccountId":"other"}""")
        write("widgets/snapshots/other.today.json", SampleJson.snapshot())

        val state = ListWidgetState.load(files, 5)

        assertEquals(ListContent.NotLoaded("acc"), ListContent.of(state, now = 0))
    }

    @Test
    fun `counts every task and offers the rest as more`() {
        val content = shown(SampleJson.snapshot())

        assertEquals(3, content.count)
        assertEquals("3 tasks", content.countLabel)
        assertEquals(listOf(1L, -4L), content.rows.map { it.row.taskId })
        assertEquals(1, content.more)
        assertEquals("$LINK/new-task?account=acc", content.newTaskLink)
        assertNull(content.message)
    }

    @Test
    fun `leaves out a row tapped done and counts one less`() {
        write("widgets/snapshots/acc.today.json", SampleJson.snapshot())
        write("widgets/host.json", """{"version":1,"activeAccountId":"acc"}""")
        WidgetActionQueue(files).add(WidgetAction("a", "acc", 1, 2_000), snapshotGeneratedAt = 1_000)

        val content = ListContent.of(ListWidgetState.load(files, 5), now = 0) as ListContent.Shown

        assertEquals(listOf(-4L), content.rows.map { it.row.taskId })
        assertEquals(2, content.count)
        assertNull(content.countLabel)
        assertEquals(1, content.more)
    }

    @Test
    fun `turns a row due today overdue once its instant passes`() {
        assertEquals(DueTone.TODAY, shown(SampleJson.snapshot(), now = 4_999).rows.first().tone)
        assertEquals(DueTone.OVERDUE, shown(SampleJson.snapshot(), now = 5_000).rows.first().tone)
        assertEquals(DueTone.NONE, shown(SampleJson.snapshot(), now = 5_000).rows[1].tone)
    }

    @Test
    fun `keeps the rows with a message while the session needs a new sign-in`() {
        val content = shown(
            SampleJson.snapshot(state = "needsReauth", extra = """"message":{"title":"Sign in again"}"""),
        )

        assertEquals(WidgetText("Sign in again", null, null), content.message)
        assertEquals(2, content.rows.size)
        assertEquals(3, content.count)
    }

    @Test
    fun `shows only the message for a removed account or a list that is gone`() {
        for (state in listOf("accountRemoved", "gone")) {
            val content = shown(SampleJson.snapshot(state = state, extra = """"message":{"title":"Removed"}"""))

            assertEquals(WidgetText("Removed", null, null), content.message)
            assertTrue(content.rows.isEmpty())
            assertFalse(content.listed)
            assertNull(content.newTaskLink)
            assertEquals(0, content.more)
            assertEquals("$LINK/configure?appWidgetId=5", content.messageLink)
        }
    }

    @Test
    fun `keeps the snapshot's message link for a session or an unconfigured widget`() {
        val messageLink = """"messageLink":"$LINK/account?account=acc""""
        val reauth = shown(SampleJson.snapshot(state = "needsReauth", extra = messageLink))
        assertEquals("$LINK/account?account=acc", reauth.messageLink)

        val removed = shown(SampleJson.snapshot(state = "accountRemoved", extra = messageLink), configured = false)
        assertEquals("$LINK/account?account=acc", removed.messageLink)
    }

    @Test
    fun `changes at the next due instant, then when it goes stale`() {
        val snapshot = Snapshot.parse(SampleJson.snapshot())!!

        assertEquals(5_000L, snapshot.nextChangeAt(now = 1_000))
        assertEquals(90_000L, snapshot.nextChangeAt(now = 5_000))
        assertNull(snapshot.nextChangeAt(now = 90_000))
    }

    private fun shown(json: String, now: Long = 0, configured: Boolean = true): ListContent.Shown {
        val state = ListWidgetState(
            appWidgetId = 5,
            configured = configured,
            key = "acc.today",
            accountId = "acc",
            snapshot = Snapshot.parse(json)!!,
            hiddenTaskIds = emptySet(),
            dynamicColor = true,
        )
        return ListContent.of(state, now) as ListContent.Shown
    }

    private fun write(path: String, text: String) {
        File(folder.root, path).apply { parentFile?.mkdirs() }.writeText(text)
    }
}
