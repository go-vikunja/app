package io.vikunja.app

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.io.ByteArrayOutputStream

class ContentFilesTest {
    private var clock = 0L
    private val waits = mutableListOf<Int>()

    // Each entry is what one read finds once something can be read; null
    // means nothing arrives during that wait.
    private fun copy(
        arrivals: List<ByteArray?>,
        maxBytes: Long = 100,
        idleMillis: Long = 1_000,
        stopped: () -> Boolean = { false },
        sink: ByteArrayOutputStream = ByteArrayOutputStream(),
    ): Long {
        val pending = ArrayDeque(arrivals)
        return copyWhileArriving(
            waitReadable = { millis ->
                waits += millis
                if (pending.isEmpty()) return@copyWhileArriving true
                if (pending.first() == null) {
                    pending.removeFirst()
                    clock += millis
                    false
                } else {
                    true
                }
            },
            read = { buffer ->
                val next = pending.removeFirstOrNull() ?: return@copyWhileArriving -1
                next.copyInto(buffer)
                next.size
            },
            sink = sink,
            maxBytes = maxBytes,
            idleMillis = idleMillis,
            stopped = stopped,
            now = { clock },
        )
    }

    @Test
    fun `copies what arrives until the end`() {
        val sink = ByteArrayOutputStream()

        val copied = copy(listOf(byteArrayOf(1, 2), null, byteArrayOf(3)), sink = sink)

        assertEquals(3L, copied)
        assertArrayEquals(byteArrayOf(1, 2, 3), sink.toByteArray())
    }

    @Test
    fun `gives up once nothing arrives for the idle limit`() {
        try {
            copy(listOf(byteArrayOf(1)) + List(20) { null })
            fail("no limit")
        } catch (_: StalledException) {
        }
        assertEquals(1_000L, clock)
    }

    @Test
    fun `bytes that keep arriving within the limit are copied, however slowly`() {
        val trickle = (1..10).flatMap { listOf(null, null, byteArrayOf(it.toByte())) }

        assertEquals(10L, copy(trickle))
        assertTrue(clock > 1_000L)
    }

    @Test
    fun `stops at once when told`() {
        var stop = false
        try {
            copy(
                listOf(byteArrayOf(1), null, null),
                stopped = { stop.also { stop = true } },
            )
            fail("not stopped")
        } catch (_: CopyStoppedException) {
        }
        assertTrue(waits.size <= 1)
    }

    @Test
    fun `more than the limit is too large`() {
        try {
            copy(listOf(ByteArray(60), ByteArray(60)))
            fail("no cap")
        } catch (_: TooLargeException) {
        }
    }

    @Test
    fun `every arrival is reported as progress`() {
        var progress = 0
        copyWhileArriving(
            waitReadable = { true },
            read = { buffer ->
                if (progress < 3) {
                    buffer[0] = 1
                    1
                } else {
                    -1
                }
            },
            sink = ByteArrayOutputStream(),
            maxBytes = 100,
            idleMillis = 1_000,
            stopped = { false },
            progressed = { progress++ },
        )

        assertEquals(3, progress)
    }

    @Test
    fun `waits in short slices so that a stop is seen soon`() {
        copy(listOf(null, null, byteArrayOf(1)))

        assertTrue(waits.all { it in 1..500 })
    }
}
