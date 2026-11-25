package io.vikunja.app.widgets

import java.io.IOException
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test

class WidgetRedrawReceiverTest {
    @Test
    fun `a redraw that fails is skipped instead of reaching the receiver's thread`() {
        runBlocking {
            redrawOrSkip { throw IOException("No space left on device") }
            redrawOrSkip { throw IllegalStateException() }
        }
    }

    @Test
    fun `a redraw that works runs once`() {
        runBlocking {
            var redraws = 0

            redrawOrSkip { redraws++ }

            assertEquals(1, redraws)
        }
    }

    @Test
    fun `a broadcast the system counts as finished already is skipped`() {
        finishOrSkip { throw IllegalStateException("Broadcast already finished") }
    }

    @Test
    fun `a broadcast is finished once`() {
        var finishes = 0

        finishOrSkip { finishes++ }

        assertEquals(1, finishes)
    }
}
