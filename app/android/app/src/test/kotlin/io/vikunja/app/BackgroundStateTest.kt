package io.vikunja.app

import org.junit.Assert.assertEquals
import org.junit.Test

class BackgroundStateTest {
    @Test
    fun `each public standby bucket has its own name`() {
        assertEquals("active", BackgroundState.bucketName(10))
        assertEquals("workingSet", BackgroundState.bucketName(20))
        assertEquals("frequent", BackgroundState.bucketName(30))
        assertEquals("rare", BackgroundState.bucketName(40))
        assertEquals("restricted", BackgroundState.bucketName(45))
    }

    @Test
    fun `any other bucket is other`() {
        assertEquals("other", BackgroundState.bucketName(5))
        assertEquals("other", BackgroundState.bucketName(50))
        assertEquals("other", BackgroundState.bucketName(-1))
    }

    @Test
    fun `a value that cannot be read is left out and the others stay`() {
        val state = BackgroundState.collect(
            linkedMapOf(
                "powerSaveMode" to { true },
                "backgroundRestricted" to { throw SecurityException() },
                "standbyBucket" to { "rare" },
            ),
        )

        assertEquals(mapOf("powerSaveMode" to true, "standbyBucket" to "rare"), state)
    }
}
