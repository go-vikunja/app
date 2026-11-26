package io.vikunja.app

import java.io.File
import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.assertThrows
import org.junit.Test

class ShareInboxTest {
    private val looked = mutableListOf<String>()

    @Test
    fun `clearing an old share leaves its replacement waiting even before announcement`() {
        val pending = PendingShare<String>()
        pending.replace("same contents")
        val older = checkNotNull(pending.current)
        pending.replace("same contents")
        val newer = checkNotNull(pending.current)

        assertFalse(pending.clear(older.id))
        assertNull(pending.forId(older.id))
        assertEquals(newer, pending.current)
        assertEquals(newer, pending.forId(newer.id))
        assertTrue(pending.clear(newer.id))
        assertNull(pending.current)
    }

    @Test
    fun `a delayed clear deletes only its own files and leaves moved uploads alone`() = withCache { root ->
        val cache = ShareCopyCache(File(root, "inbox"))
        val first = cache.forShare(1)
        val oldCopy = first.copy("old")
        val moved = File(root, "upload")
        assertTrue(first.copy("uploaded").renameTo(moved))
        val second = cache.forShare(2)
        val newCopy = second.copy("new")

        first.purge()

        assertFalse(oldCopy.parentFile!!.exists())
        assertEquals("new", newCopy.readText())
        assertEquals("uploaded", moved.readText())
    }

    @Test
    fun `startup cleanup never sweeps the current process even when it reuses a share ID`() = withCache { root ->
        val previous = ShareCopyCache(root).forShare(1).copy("previous")
        val currentCache = ShareCopyCache(root)
        val current = currentCache.forShare(1).copy("current")

        currentCache.purgePreviousProcesses()

        assertFalse(previous.exists())
        assertEquals("current", current.readText())
    }

    @Test
    fun `cancelling one copy removes its partial file and prevents a late open`() = withCache { root ->
        val share = ShareCopyCache(root).forShare(1)
        val finished = share.copy("ready")
        val partial = share.target()
        share.open(partial) { false }.use { sink ->
            sink.write(1)
            share.discard(partial)
            // An already-open descriptor no longer names a file.
            sink.write(2)
        }
        val late = share.target()

        assertThrows(CopyStoppedException::class.java) { share.open(late) { true } }
        assertFalse(partial.exists())
        assertFalse(late.exists())
        assertEquals("ready", finished.readText())
        share.purge()
        assertThrows(CopyStoppedException::class.java) { share.open(late) { true } }
        assertFalse(late.parentFile!!.exists())
    }

    private fun ShareCopyDirectory.copy(text: String): File =
        target().also { target -> open(target) { false }.use { it.write(text.toByteArray()) } }

    private fun withCache(test: (File) -> Unit) {
        val cache = Files.createTempDirectory(File(".").toPath(), "share-cache-test-").toFile()
        try {
            test(cache)
        } finally {
            cache.deleteRecursively()
        }
    }

    private fun isForeign(
        scheme: String?,
        authority: String?,
        providers: Map<String, String> = mapOf(GALLERY to "com.example.gallery"),
    ): Boolean = ShareInbox.isForeignContent(scheme, authority, OWN) {
        looked += it
        providers[it]
    }

    @Test
    fun `another app's content URI is read`() {
        assertTrue(isForeign("content", GALLERY))
        assertEquals(listOf(GALLERY), looked)
    }

    @Test
    fun `a provider the app cannot see is another app's`() {
        assertTrue(isForeign("content", "com.example.hidden"))
    }

    @Test
    fun `only content URIs are read, never a file, a resource or a web address`() {
        for (scheme in listOf("file", "android.resource", "http", "https", "Content", "CONTENT", "", null)) {
            assertFalse("$scheme", isForeign(scheme, GALLERY))
        }
        assertEquals(emptyList<String>(), looked)
    }

    @Test
    fun `a content URI without an authority is not read`() {
        assertFalse(isForeign("content", null))
        assertFalse(isForeign("content", ""))
        assertFalse(isForeign("content", "10@"))
        assertEquals(emptyList<String>(), looked)
    }

    @Test
    fun `the app's own providers are never read, also through another user or user info`() {
        for (authority in listOf(
            "$OWN.files",
            "$OWN.flutter.share_provider",
            "$OWN.androidx-startup",
            "0@$OWN.files",
            "10@$OWN.files",
            "$GALLERY@$OWN.files",
        )) {
            assertFalse(authority, isForeign("content", authority))
        }
        assertEquals(emptyList<String>(), looked)
    }

    @Test
    fun `a provider of the app's under another name is never read`() {
        assertFalse(isForeign("content", "provider.of.a.library", mapOf("provider.of.a.library" to OWN)))
        assertEquals(listOf("provider.of.a.library"), looked)
    }

    @Test
    fun `the provider after the last @ is the one looked up`() {
        assertTrue(isForeign("content", "10@$GALLERY"))
        assertTrue(isForeign("content", "$OWN.files@$GALLERY"))
        assertEquals(listOf(GALLERY, GALLERY), looked)
    }

    @Test
    fun `an authority that only starts like the app's package is refused too`() {
        assertFalse(isForeign("content", "${OWN}lication.provider", mapOf("${OWN}lication.provider" to "other")))
    }

    @Test
    fun `a lookup that fails is refused, as it cannot rule out the app's own provider`() {
        assertFalse(ShareInbox.isForeignContent("content", GALLERY, OWN) { throw IllegalStateException() })
    }

    @Test
    fun `a long text is cut after the last whole character that fits`() {
        val emoji = "\uD83D\uDE00"
        assertEquals("a$emoji", ShareInbox.cutText("a$emoji$emoji", 4))
        assertEquals("a$emoji", ShareInbox.cutText("a$emoji", 4))
        assertEquals("abcd", ShareInbox.cutText("abcdef", 4))
    }

    private companion object {
        const val OWN = "io.vikunja.app"
        const val GALLERY = "com.example.gallery.provider"
    }
}
