package io.vikunja.app

import android.content.Intent
import io.vikunja.app.OwnTask.Start
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OwnTaskTest {
    @Test
    fun `a start without a new task above another app's activity goes to the app's own task`() {
        assertEquals(Start.ANOTHER_TASK, start(isTaskRoot = false, flags = 0))
        assertEquals(Start.ANOTHER_TASK, start(isTaskRoot = false, flags = Intent.FLAG_ACTIVITY_SINGLE_TOP))
    }

    @Test
    fun `the launcher's start, a relaunch and the app's own links stay`() {
        assertEquals(Start.OWN, start(isTaskRoot = true, flags = LAUNCHER, launcher = true))
        assertEquals(Start.OWN, start(isTaskRoot = true, flags = 0))
        assertEquals(Start.OWN, start(isTaskRoot = false, flags = OwnTask.FLAGS))
        assertEquals(Start.OWN, start(isTaskRoot = true, flags = 0, restored = true))
    }

    @Test
    fun `a reminder tap above a picker in the app's task is a second copy that hands its intent over`() {
        assertEquals(Start.AGAIN, start(isTaskRoot = false, flags = Intent.FLAG_ACTIVITY_NEW_TASK, rootIsMain = true))
        assertEquals(Start.AGAIN, start(isTaskRoot = false, flags = OwnTask.FLAGS, rootIsMain = true))
        assertEquals(Start.AGAIN, start(isTaskRoot = false, flags = 0, rootIsMain = true))
    }

    @Test
    fun `the app icon above a picker in the app's task is a second copy that only finishes`() {
        assertEquals(
            Start.AGAIN_FROM_LAUNCHER,
            start(isTaskRoot = false, flags = LAUNCHER, rootIsMain = true, launcher = true),
        )
    }

    @Test
    fun `the task's root is looked up only for a fresh start that is not the root`() {
        var lookups = 0
        val lookup = {
            lookups++
            true
        }
        OwnTask.start(isTaskRoot = true, flags = 0, restored = false, launcher = false, rootIsMainActivity = lookup)
        OwnTask.start(isTaskRoot = false, flags = 0, restored = true, launcher = false, rootIsMainActivity = lookup)
        assertEquals(0, lookups)

        OwnTask.start(isTaskRoot = false, flags = 0, restored = false, launcher = false, rootIsMainActivity = lookup)
        assertEquals(1, lookups)
    }

    @Test
    fun `a restored activity that is not the root keeps the rule for another app's task`() {
        assertEquals(Start.ANOTHER_TASK, start(isTaskRoot = false, flags = 0, rootIsMain = true, restored = true))
        assertEquals(
            Start.OWN,
            start(isTaskRoot = false, flags = Intent.FLAG_ACTIVITY_NEW_TASK, rootIsMain = true, restored = true),
        )
    }

    @Test
    fun `a second copy finishes before it hands its intent over, so the restart reaches the first`() {
        assertEquals(OwnTask.Plan(finishFirst = false, restart = true), Start.ANOTHER_TASK.plan)
        assertEquals(OwnTask.Plan(finishFirst = true, restart = true), Start.AGAIN.plan)
        assertEquals(OwnTask.Plan(finishFirst = true, restart = false), Start.AGAIN_FROM_LAUNCHER.plan)
    }

    @Test
    fun `a second copy finishes, then hands the caller's intent over, then starts Flutter without its extras`() {
        assertEquals(
            listOf("finish", "start restart(caller)", "set dropped(caller)", "create", "finish"),
            handOver(Start.AGAIN),
        )
    }

    @Test
    fun `a start in another app's task hands the caller's intent over before it finishes`() {
        assertEquals(
            listOf("start restart(caller)", "set dropped(caller)", "create", "finish"),
            handOver(Start.ANOTHER_TASK),
        )
    }

    @Test
    fun `a second copy from the app icon only finishes, without Flutter getting the caller's extras`() {
        assertEquals(listOf("finish", "set dropped(caller)", "create", "finish"), handOver(Start.AGAIN_FROM_LAUNCHER))
    }

    @Test
    fun `only the launcher's own intent counts as the app icon`() {
        val launcherCategory = setOf(Intent.CATEGORY_LAUNCHER)
        assertTrue(OwnTask.isLauncherStart(Intent.ACTION_MAIN, launcherCategory))
        // A reminder tap and a home screen shortcut keep the launcher's category.
        assertFalse(OwnTask.isLauncherStart("SELECT_NOTIFICATION", launcherCategory))
        assertFalse(OwnTask.isLauncherStart(Intent.ACTION_RUN, launcherCategory))
        assertFalse(OwnTask.isLauncherStart(Intent.ACTION_MAIN, null))
        assertFalse(OwnTask.isLauncherStart(null, launcherCategory))
    }

    @Test
    fun `the restart reuses the app's activity in its own task`() {
        assertEquals(
            Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP,
            OwnTask.FLAGS,
        )
    }

    private fun handOver(start: Start): List<String> {
        val steps = mutableListOf<String>()
        OwnTask.handOver(
            plan = start.plan!!,
            intent = "caller",
            finish = { steps.add("finish") },
            restart = { "restart($it)" },
            start = { steps.add("start $it") },
            withoutExtras = { "dropped($it)" },
            setIntent = { steps.add("set $it") },
            create = { steps.add("create") },
        )
        return steps
    }

    private fun start(
        isTaskRoot: Boolean,
        flags: Int,
        rootIsMain: Boolean = false,
        launcher: Boolean = false,
        restored: Boolean = false,
    ) = OwnTask.start(isTaskRoot, flags, restored, launcher) { rootIsMain }

    private companion object {
        const val LAUNCHER = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
    }
}
