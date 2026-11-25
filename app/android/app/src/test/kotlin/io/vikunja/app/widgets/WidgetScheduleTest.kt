package io.vikunja.app.widgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetScheduleTest {
    private val plan = WidgetSchedulePlan()
    private val snapshot =
        Snapshot.parse(SampleJson.snapshot())!!.copy(changesAt = listOf(5_000L), validUntil = 90_000L)

    @Test
    fun `a list past its end asks the app for a new one only once`() {
        assertFalse(plan.refreshes(snapshot, now = 89_999))
        assertTrue(plan.refreshes(snapshot, now = 90_000))
        assertFalse(plan.refreshes(snapshot, now = 90_000))
        assertFalse(plan.refreshes(snapshot, now = 200_000))
    }

    @Test
    fun `a list past a later end asks again`() {
        assertTrue(plan.refreshes(snapshot, now = 90_000))

        assertTrue(plan.refreshes(snapshot.copy(validUntil = 180_000), now = 180_000))
    }

    @Test
    fun `an end earlier than one already asked for asks nothing`() {
        assertTrue(plan.refreshes(snapshot.copy(validUntil = 180_000), now = 200_000))

        assertFalse(plan.refreshes(snapshot, now = 200_000))
    }

    @Test
    fun `sets the redraw alarm for the next due instant`() {
        assertEquals(5_000L, plan.alarmFor(snapshot, now = 1_000))
    }

    @Test
    fun `keeps the alarm while it fires by the next change`() {
        plan.alarmFor(snapshot, now = 1_000)

        assertNull(plan.alarmFor(snapshot, now = 2_000))
        assertNull(plan.alarmFor(snapshot.copy(changesAt = listOf(7_000L)), now = 2_000))
    }

    @Test
    fun `moves the alarm to an earlier change`() {
        plan.alarmFor(snapshot, now = 1_000)

        assertEquals(3_000L, plan.alarmFor(snapshot.copy(changesAt = listOf(3_000L)), now = 1_000))
    }

    @Test
    fun `sets the next alarm once the last one has fired`() {
        plan.alarmFor(snapshot, now = 1_000)

        assertEquals(90_000L, plan.alarmFor(snapshot, now = 5_000))
    }

    @Test
    fun `sets no alarm for a list with nothing left to change`() {
        assertNull(plan.alarmFor(snapshot, now = 90_000))
    }

    @Test
    fun `asks once per key for a list without a snapshot`() {
        assertTrue(plan.asksFor("acc.today"))
        assertFalse(plan.asksFor("acc.today"))
        assertTrue(plan.asksFor("acc.label_3"))
    }
}
