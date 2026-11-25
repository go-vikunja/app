package io.vikunja.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ShareLimitsTest {
    @Test
    fun `a description is delivered only while its share is still the pending one`() {
        val older = Any()
        val newer = Any()
        var described = 0
        val map = mapOf<String, Any?>("text" to "x")

        assertEquals(map, ShareInbox.answerFor(newer, newer) { described++; map })
        assertNull(ShareInbox.answerFor(older, newer) { described++; map })
        assertNull(ShareInbox.answerFor(older, null) { described++; map })
        assertEquals(1, described)
    }

    @Test
    fun `a copy not opened in time is overdue, an opened one once nothing arrives for the idle limit`() {
        fun overdue(now: Long, lastProgress: Long?) =
            ShareInbox.copyOverdue(now, started = 0, lastProgress = lastProgress, openLimit = 300, idleLimit = 30)

        assertFalse(overdue(299, null))
        assertTrue(overdue(300, null))
        assertFalse(overdue(1_000, 980))
        assertTrue(overdue(1_000, 970))
    }

    @Test
    fun `each described file has the full limit, counted from the last answer`() {
        assertFalse(ShareInbox.describeOverdue(now = 25, lastAnswer = 16, limit = 10))
        assertTrue(ShareInbox.describeOverdue(now = 26, lastAnswer = 16, limit = 10))
    }

    @Test
    fun `slots run out at the cap and come back when given`() {
        val slots = CallSlots(2)

        assertTrue(slots.tryTake())
        assertTrue(slots.tryTake())
        assertFalse(slots.tryTake())
        slots.give()
        assertTrue(slots.tryTake())
        assertFalse(slots.tryTake())
    }
}
