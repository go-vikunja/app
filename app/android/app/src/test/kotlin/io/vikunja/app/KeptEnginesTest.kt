package io.vikunja.app

import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class KeptEnginesTest {
    @Test
    fun `every activity gets an engine id of its own`() {
        assertNotEquals(KeptEngines.newId(), KeptEngines.newId())
    }

    @Test
    fun `a relaunched activity finds the window state of its engine`() {
        val id = KeptEngines.newId()
        KeptEngines.state(id).window.secure = true

        assertSame(KeptEngines.state(id), KeptEngines.state(id))
        assertTrue(KeptEngines.state(id).window.secure)
        KeptEngines.forget(id)
    }

    @Test
    fun `one engine's window state does not reach another`() {
        val first = KeptEngines.newId()
        val second = KeptEngines.newId()
        KeptEngines.state(first).window.backMovesTaskToBack = true

        assertFalse(KeptEngines.state(second).window.backMovesTaskToBack)
        KeptEngines.forget(first)
        KeptEngines.forget(second)
    }

    @Test
    fun `one engine's pending pick or save does not reach another`() {
        val first = KeptEngines.newId()
        val second = KeptEngines.newId()
        KeptEngines.state(first).pick.start(RecordingResult())
        KeptEngines.state(first).saveAs.start(File("a") to RecordingResult())

        assertFalse(KeptEngines.state(second).pick.isPending)
        assertNull(KeptEngines.state(second).saveAs.take())
        assertTrue(KeptEngines.state(first).pick.isPending)
        assertTrue(KeptEngines.state(first).saveAs.isPending)
        KeptEngines.forget(first)
        KeptEngines.forget(second)
    }

    @Test
    fun `a forgotten engine's state starts empty`() {
        val id = KeptEngines.newId()
        KeptEngines.state(id).apply {
            window.secure = true
            window.recentsScreenshotEnabled = false
            window.backMovesTaskToBack = true
            pick.start(RecordingResult())
            saveAs.start(File("a") to RecordingResult())
        }

        KeptEngines.forget(id)

        val fresh = KeptEngines.state(id)
        assertFalse(fresh.window.secure)
        assertNull(fresh.window.recentsScreenshotEnabled)
        assertFalse(fresh.window.backMovesTaskToBack)
        assertFalse(fresh.pick.isPending)
        assertTrue(fresh.picked.isEmpty())
        assertFalse(fresh.saveAs.isPending)
        KeptEngines.forget(id)
    }

    @Test
    fun `a pick kept on detach waits for the next activity's result`() {
        val id = KeptEngines.newId()
        val result = RecordingResult()
        KeptEngines.state(id).pick.start(result)

        KeptEngines.state(id).pick.release(keep = true)

        assertFalse(result.answered)
        assertSame(result, KeptEngines.state(id).pick.take())
        assertFalse(KeptEngines.state(id).pick.isPending)
        KeptEngines.forget(id)
    }

    @Test
    fun `a pick not kept on detach is answered with nothing`() {
        val id = KeptEngines.newId()
        val result = RecordingResult()
        KeptEngines.state(id).pick.start(result)

        KeptEngines.state(id).pick.release(keep = false)

        assertEquals(listOf(emptyList<Any>()), result.successes)
        assertNull(KeptEngines.state(id).pick.take())
        KeptEngines.forget(id)
    }

    @Test
    fun `a save kept on detach waits for the next activity's result`() {
        val id = KeptEngines.newId()
        val file = File("a")
        val result = RecordingResult()
        KeptEngines.state(id).saveAs.start(file to result)

        KeptEngines.state(id).saveAs.release(keep = true)

        assertFalse(result.answered)
        assertEquals(file to result, KeptEngines.state(id).saveAs.take())
        KeptEngines.forget(id)
    }

    @Test
    fun `a save not kept on detach is answered with false`() {
        val id = KeptEngines.newId()
        val result = RecordingResult()
        KeptEngines.state(id).saveAs.start(File("a") to result)

        KeptEngines.state(id).saveAs.release(keep = false)

        assertEquals(listOf(false), result.successes)
        assertNull(KeptEngines.state(id).saveAs.take())
        KeptEngines.forget(id)
    }

    @Test
    fun `a call already answered is not answered again on detach`() {
        val result = RecordingResult()
        val state = EngineState()
        state.pick.start(result)
        state.pick.take()?.success(listOf("picked"))

        state.pick.release(keep = false)

        assertEquals(listOf(listOf("picked")), result.successes)
    }

    private class RecordingResult : MethodChannel.Result {
        val successes = mutableListOf<Any?>()
        var answered = false
            private set

        override fun success(result: Any?) {
            successes.add(result)
            answered = true
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            answered = true
        }

        override fun notImplemented() {
            answered = true
        }
    }
}
