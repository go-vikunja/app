package io.vikunja.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ViewTypeTest {
    private val types = mapOf(
        "pdf" to "application/pdf",
        "png" to "image/png",
        "txt" to "text/plain",
        "html" to "text/html",
        "htm" to "text/html",
        "xhtml" to "application/xhtml+xml",
        "xml" to "text/xml",
        "svg" to "image/svg+xml",
        "rss" to "application/rss+xml",
        "md" to "text/markdown",
    )

    private fun viewTypeOf(name: String, sent: String) = viewType(name, sent) { types[it] }

    @Test
    fun `the type follows the file's name, not the type the server sent`() {
        assertEquals("application/pdf", viewTypeOf("report.pdf", "text/plain"))
        assertEquals("image/png", viewTypeOf("Scan.PNG", "application/octet-stream"))
        assertEquals("text/plain", viewTypeOf("spoof.txt", "image/png"))
    }

    @Test
    fun `a name without a known extension keeps the sent type`() {
        assertEquals("application/zip", viewTypeOf("archive.unknownext", "application/zip"))
        assertEquals("text/plain", viewTypeOf("README", "text/plain"))
        assertEquals("text/plain", viewTypeOf("notes.", "text/plain"))
    }

    @Test
    fun `a name of a known type decides alone, so a page sent for README_md opens as Markdown`() {
        assertEquals("text/markdown", viewTypeOf("README.md", "text/html"))
        assertEquals("application/pdf", viewTypeOf("invoice.pdf", "image/svg+xml"))
    }

    @Test
    fun `web pages, XML and SVG are never opened, by their name or, without a known one, by the sent type`() {
        for (name in listOf("invoice.html", "a.HTM", "b.xhtml", "c.xml", "d.svg", "feed.rss")) {
            assertNull(name, viewTypeOf(name, "application/pdf"))
        }
        for (sent in listOf(
            "text/html",
            "application/xhtml+xml",
            "text/xml",
            "application/xml",
            "image/svg+xml",
            "application/atom+xml",
            "TEXT/HTML",
        )) {
            assertNull(sent, viewTypeOf("invoice", sent))
            assertNull(sent, viewTypeOf("invoice.unknownext", sent))
        }
    }
}
