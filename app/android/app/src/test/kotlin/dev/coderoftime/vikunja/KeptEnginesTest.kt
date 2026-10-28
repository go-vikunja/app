package dev.coderoftime.vikunja

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class KeptEnginesTest {
    @Test
    fun `every activity gets an engine id of its own`() {
        assertNotEquals(KeptEngines.newId(), KeptEngines.newId())
    }

    @Test
    fun `a relaunched activity finds the window state of its engine`() {
        val id = KeptEngines.newId()
        KeptEngines.window(id).secure = true

        assertSame(KeptEngines.window(id), KeptEngines.window(id))
        assertTrue(KeptEngines.window(id).secure)
        KeptEngines.forget(id)
    }

    @Test
    fun `one engine's window state does not reach another`() {
        val first = KeptEngines.newId()
        val second = KeptEngines.newId()
        KeptEngines.window(first).backMovesTaskToBack = true

        assertFalse(KeptEngines.window(second).backMovesTaskToBack)
        KeptEngines.forget(first)
        KeptEngines.forget(second)
    }

    @Test
    fun `a released engine's window state is gone`() {
        val id = KeptEngines.newId()
        KeptEngines.window(id).apply {
            secure = true
            recentsScreenshotEnabled = false
            backMovesTaskToBack = true
        }

        KeptEngines.forget(id)

        val fresh = KeptEngines.window(id)
        assertFalse(fresh.secure)
        assertNull(fresh.recentsScreenshotEnabled)
        assertFalse(fresh.backMovesTaskToBack)
        KeptEngines.forget(id)
    }
}
