package io.vikunja.app.widget

import io.vikunja.app.widgets.TasksWidget
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LegacyWidgetsTest {
    @Test
    fun `names the previous app's receiver class`() {
        assertEquals("io.vikunja.app.widget.AppWidgetReciever", LegacyWidgets.RECEIVER)
        assertEquals(AppWidgetReciever::class.java.name, LegacyWidgets.RECEIVER)
    }

    @Test
    fun `draws the Tasks widget`() {
        assertTrue(AppWidgetReciever().glanceAppWidget is TasksWidget)
    }
}
