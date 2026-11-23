package io.vikunja.app

import android.content.Intent
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LaunchReplayTest {
    @Test
    fun `a restore after the process died or the activity was destroyed replays the intent that started the task`() {
        assertTrue(isReplay(flags = 0, restored = true))
        assertTrue(isReplay(flags = LAUNCHER, restored = true))
        assertTrue(isReplay(flags = Intent.FLAG_ACTIVITY_NEW_TASK, restored = true))
        assertTrue(isReplay(flags = OwnTask.FLAGS, restored = true))
    }

    @Test
    fun `a relaunch for a configuration change keeps the intent Dart may not have read yet`() {
        assertFalse(isReplay(flags = 0, restored = true, relaunchedForConfigChange = true))
        assertFalse(isReplay(flags = LAUNCHER, restored = true, relaunchedForConfigChange = true))
        assertFalse(isReplay(flags = OwnTask.FLAGS, restored = true, relaunchedForConfigChange = true))
    }

    @Test
    fun `a start from Recents replays it`() {
        assertTrue(isReplay(flags = HISTORY, restored = false))
        assertTrue(isReplay(flags = LAUNCHER or HISTORY, restored = false))
    }

    @Test
    fun `a restore or relaunch from Recents replays it`() {
        assertTrue(isReplay(flags = LAUNCHER or HISTORY, restored = true))
        assertTrue(isReplay(flags = LAUNCHER or HISTORY, restored = true, relaunchedForConfigChange = true))
    }

    @Test
    fun `a fresh start is no replay`() {
        assertFalse(isReplay(flags = 0, restored = false))
        assertFalse(isReplay(flags = LAUNCHER, restored = false))
        assertFalse(isReplay(flags = Intent.FLAG_ACTIVITY_NEW_TASK, restored = false))
        assertFalse(isReplay(flags = OwnTask.FLAGS, restored = false))
    }

    private fun isReplay(flags: Int, restored: Boolean, relaunchedForConfigChange: Boolean = false) =
        LaunchReplay.isReplay(flags, restored, relaunchedForConfigChange)

    private companion object {
        const val LAUNCHER = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
        const val HISTORY = Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY
    }
}
