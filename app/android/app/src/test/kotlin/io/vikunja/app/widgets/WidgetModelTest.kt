package io.vikunja.app.widgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetModelTest {
    @Test
    fun `parses a snapshot as the app writes it`() {
        val snapshot = Snapshot.parse(SampleJson.snapshot())!!

        assertEquals("acc.today", snapshot.key)
        assertEquals("acc", snapshot.accountId)
        assertEquals(SnapshotState.OK, snapshot.state)
        assertEquals("Today", snapshot.title)
        assertNull(snapshot.subtitle)
        assertEquals(1_000L, snapshot.generatedAt)
        assertEquals(90_000L, snapshot.validUntil)
        assertEquals(listOf(5_000L), snapshot.changesAt)
        assertEquals(3, snapshot.total)
        assertEquals("+1 more", snapshot.moreLabel)
        assertEquals("3 tasks", snapshot.countLabel)
        assertEquals(WidgetText("All done", "Nothing left", null), snapshot.empty)
        assertNull(snapshot.message)
        assertEquals("$LINK/list?account=acc&kind=today", snapshot.link)
        assertEquals("New task", snapshot.newTaskLabel)

        val row = snapshot.rows.first()
        assertEquals(1L, row.taskId)
        assertEquals("Water the plants", row.title)
        assertEquals("Today, 14:30", row.dueLabel)
        assertEquals(5_000L, row.dueAt)
        assertEquals(DueTone.TODAY, row.tone)
        assertEquals("High", row.priorityLabel)
        assertEquals(3, row.priorityLevel)
        assertEquals("Home", row.projectTitle)
        assertEquals(0xFF1973FF.toInt(), row.projectColor)
        assertTrue(row.canDone)
        assertEquals("Water the plants, due today", row.semanticsLabel)
        assertEquals("Mark “Water the plants” done", row.doneLabel)
        assertEquals("$LINK/task/1?account=acc", row.link)

        val second = snapshot.rows[1]
        assertEquals(-4L, second.taskId)
        assertNull(second.dueLabel)
        assertEquals(DueTone.NONE, second.tone)
        assertNull(second.projectColor)
        assertFalse(second.canDone)
    }

    @Test
    fun `reads the states and messages`() {
        val snapshot = Snapshot.parse(
            SampleJson.snapshot(
                state = "needsReauth",
                extra = """"message":{"title":"Sign in again","body":"Your session ended","action":"Open"}""",
            ),
        )!!

        assertEquals(SnapshotState.NEEDS_REAUTH, snapshot.state)
        assertEquals(WidgetText("Sign in again", "Your session ended", "Open"), snapshot.message)
        assertEquals(SnapshotState.GUEST_ENDED, Snapshot.parse(SampleJson.snapshot(state = "guestEnded"))!!.state)
        assertEquals(SnapshotState.ACCOUNT_REMOVED, Snapshot.parse(SampleJson.snapshot(state = "accountRemoved"))!!.state)
        assertEquals(SnapshotState.GONE, Snapshot.parse(SampleJson.snapshot(state = "gone"))!!.state)
    }

    @Test
    fun `skips what it cannot read`() {
        assertNull(Snapshot.parse(SampleJson.snapshot(version = 2)))
        assertNull(Snapshot.parse(SampleJson.snapshot(state = "sleeping")))
        assertNull(Snapshot.parse("""{"v":1,"key":"acc.today"}"""))
        assertNull(Snapshot.parse("not json"))
        assertNull(Snapshot.parse(SampleJson.snapshot(rows = """[{"id":1,"title":"No labels"}]""")))
    }

    @Test
    fun `parses project colours with or without a hash`() {
        assertEquals(0xFF00FF00.toInt(), Snapshot.colorOf("00ff00"))
        assertEquals(0xFF00FF00.toInt(), Snapshot.colorOf("#00FF00"))
        assertNull(Snapshot.colorOf("0f0"))
        assertNull(Snapshot.colorOf("zzzzzz"))
        assertNull(Snapshot.colorOf(null))
    }

    @Test
    fun `reads an instance config in the plugin's format`() {
        val config = InstanceConfig.parse(
            """{"version":1,"key":"acc.project_12","v":1,"account":"acc","kind":"project","id":12}""",
        )

        assertEquals(InstanceConfig("acc.project_12", "acc"), config)
        assertEquals(
            InstanceConfig(null, "acc"),
            InstanceConfig.parse("""{"version":1,"key":null,"v":1,"account":"acc","kind":"today"}"""),
        )
        assertNull(InstanceConfig.parse("[]"))
    }

    @Test
    fun `reads the host settings with dynamic colour on by default`() {
        val host = HostSettings.parse("""{"version":1,"activeAccountId":"acc","dynamicColor":false}""")!!

        assertEquals("acc", host.activeAccountId)
        assertFalse(host.dynamicColor)
        assertTrue(HostSettings.parse("""{"version":1,"activeAccountId":null}""")!!.dynamicColor)
    }

    @Test
    fun `round trips a widget action`() {
        val action = WidgetAction("id-1", "acc", -7, 1_234L)

        assertEquals(action, WidgetAction.parse(action.toJson()))
        assertNull(WidgetAction.parse("""{"version":1,"id":"","accountId":"acc","taskId":1,"createdAt":1}"""))
        assertNull(WidgetAction.parse("""{"version":1,"id":"x","accountId":"acc","createdAt":1}"""))
    }
}

internal const val LINK = "vikunja-io.vikunja.app://widget"

internal object SampleJson {
    fun row(
        id: Long,
        title: String,
        tone: String = "none",
        extra: String = "",
        canDone: Boolean = true,
        label: String = title,
    ): String {
        val fields = listOf(
            """"id":$id""",
            """"title":"$title"""",
            """"tone":"$tone"""",
            """"canDone":$canDone""",
            """"label":"$label"""",
            """"doneLabel":"Mark “$title” done"""",
            """"link":"$LINK/task/$id?account=acc"""",
        ) + listOfNotNull(extra.ifEmpty { null })
        return fields.joinToString(prefix = "{", postfix = "}")
    }

    val defaultRows = listOf(
        row(
            1,
            "Water the plants",
            tone = "today",
            extra = """"due":"Today, 14:30","dueAt":5000,"priority":"High","priorityLevel":3,""" +
                """"project":"Home","color":"1973ff"""",
            label = "Water the plants, due today",
        ),
        row(-4, "Call the plumber", canDone = false),
    ).joinToString(prefix = "[", postfix = "]")

    fun snapshot(
        version: Int = 1,
        state: String = "ok",
        generatedAt: Long = 1_000L,
        rows: String = defaultRows,
        total: Int = 3,
        extra: String = "",
    ): String = listOf(
        """"v":$version""",
        """"key":"acc.today"""",
        """"account":"acc"""",
        """"state":"$state"""",
        """"title":"Today"""",
        """"generatedAt":$generatedAt""",
        """"validUntil":90000""",
        """"changesAt":[5000]""",
        """"rows":$rows""",
        """"total":$total""",
        """"more":1""",
        """"moreLabel":"+1 more"""",
        """"countLabel":"3 tasks"""",
        """"empty":{"title":"All done","body":"Nothing left"}""",
        """"link":"$LINK/list?account=acc&kind=today"""",
        """"newTaskLink":"$LINK/new-task?account=acc"""",
        """"newTaskLabel":"New task"""",
    ).plus(listOfNotNull(extra.ifEmpty { null })).joinToString(prefix = "{", postfix = "}")
}
