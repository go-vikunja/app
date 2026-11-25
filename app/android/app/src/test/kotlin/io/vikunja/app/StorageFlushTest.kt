package io.vikunja.app

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.vikunja.vikunja_storage_flush.answerFlush
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class StorageFlushTest {
    private val flush = MethodCall("flushSharedPreferences", mapOf("name" to "FlutterSecureStorage"))
    private val committed = mutableListOf<String>()
    private val result = RecordingResult()

    @Test
    fun `flushes the file the Dart side names`() {
        answerFlush(flush, result, commit(written = true))

        assertEquals(listOf("FlutterSecureStorage"), committed)
        assertEquals(listOf(listOf("success", null)), result.answers)
    }

    @Test
    fun `a failed write reaches the Dart side as an error`() {
        answerFlush(flush, result, commit(written = false))

        assertEquals(listOf("FlutterSecureStorage"), committed)
        assertEquals(listOf(listOf("error", "io")), result.answers)
    }

    @Test
    fun `a call without a name writes nothing`() {
        answerFlush(MethodCall("flushSharedPreferences", emptyMap<String, Any>()), result, commit(written = true))

        assertTrue(committed.isEmpty())
        assertEquals(listOf(listOf("error", "argument")), result.answers)
    }

    @Test
    fun `answers other methods as not implemented`() {
        answerFlush(MethodCall("flush", mapOf("name" to "FlutterSecureStorage")), result, commit(written = true))

        assertTrue(committed.isEmpty())
        assertEquals(listOf(listOf("notImplemented")), result.answers)
    }

    private fun commit(written: Boolean): (String) -> Boolean = { name ->
        committed.add(name)
        written
    }

    private class RecordingResult : MethodChannel.Result {
        val answers = mutableListOf<List<Any?>>()

        override fun success(result: Any?) {
            answers.add(listOf("success", result))
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            answers.add(listOf("error", errorCode))
        }

        override fun notImplemented() {
            answers.add(listOf("notImplemented"))
        }
    }
}
