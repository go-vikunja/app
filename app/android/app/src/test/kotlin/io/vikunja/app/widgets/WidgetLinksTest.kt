package io.vikunja.app.widgets

import org.junit.Assert.assertEquals
import org.junit.Test

class WidgetLinksTest {
    @Test
    fun `carries the widget-link key when the app wrote one`() {
        assertEquals("$LINK/configure?appWidgetId=5&k=$KEY", WidgetLinks.configureLink(5, KEY))
        assertEquals("$LINK/open?account=acc&k=$KEY", WidgetLinks.openLink("acc", KEY))
        assertEquals("$LINK/new-task?account=acc&k=$KEY", WidgetLinks.newTaskLink("acc", KEY))
        assertEquals("$LINK/open?k=$KEY", WidgetLinks.openLink(null, KEY))
    }

    @Test
    fun `leaves the key out before the app wrote one`() {
        assertEquals("$LINK/configure?appWidgetId=5", WidgetLinks.configureLink(5, null))
        assertEquals("$LINK/open?account=acc", WidgetLinks.openLink("acc", null))
        assertEquals("$LINK/new-task", WidgetLinks.newTaskLink(null, null))
        assertEquals("$LINK/open", WidgetLinks.openLink(null, null))
    }

    @Test
    fun `encodes the query values`() {
        assertEquals("$LINK/open?account=a+b%26k%3Dx&k=c%2Fd", WidgetLinks.openLink("a b&k=x", "c/d"))
    }

    @Test
    fun `reads the key from host json`() {
        val host = HostSettings.parse("""{"version":1,"activeAccountId":"acc","linkKey":"$KEY"}""")!!

        assertEquals(KEY, host.linkKey)
        assertEquals(null, HostSettings.parse("""{"version":1,"activeAccountId":"acc"}""")!!.linkKey)
        assertEquals(null, HostSettings.parse("""{"version":1,"linkKey":""}""")!!.linkKey)
    }

    @Test
    fun `hands the key to what a list widget builds`() {
        val state = ListWidgetState(
            appWidgetId = 5,
            configured = false,
            key = null,
            accountId = null,
            snapshot = null,
            hiddenTaskIds = emptySet(),
            dynamicColor = true,
            linkKey = KEY,
        )

        assertEquals(ListContent.SetUp(5, KEY), ListContent.of(state, now = 0))
        assertEquals(
            ListContent.NotLoaded("acc", KEY),
            ListContent.of(state.copy(configured = true, accountId = "acc"), now = 0),
        )
    }

    private companion object {
        const val LINK = "vikunja-io.vikunja.app://widget"
        const val KEY = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8"
    }
}
