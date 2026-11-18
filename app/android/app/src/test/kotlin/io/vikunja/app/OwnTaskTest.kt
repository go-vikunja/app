package io.vikunja.app

import android.content.Intent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OwnTaskTest {
    @Test
    fun `a start without a new task above another app's activity goes to the app's own task`() {
        assertTrue(OwnTask.startedInAnotherTask(isTaskRoot = false, flags = 0))
        assertTrue(
            OwnTask.startedInAnotherTask(isTaskRoot = false, flags = Intent.FLAG_ACTIVITY_SINGLE_TOP),
        )
    }

    @Test
    fun `the launcher's start, a relaunch and the app's own links stay`() {
        assertFalse(
            OwnTask.startedInAnotherTask(
                isTaskRoot = true,
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED,
            ),
        )
        assertFalse(OwnTask.startedInAnotherTask(isTaskRoot = true, flags = 0))
        assertFalse(OwnTask.startedInAnotherTask(isTaskRoot = false, flags = OwnTask.FLAGS))
    }

    @Test
    fun `the restart reuses the app's activity in its own task`() {
        assertEquals(
            Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP,
            OwnTask.FLAGS,
        )
    }
}
