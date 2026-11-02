package dev.coderoftime.rurana

import android.provider.Settings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AppLocaleSettingsTest {
    @Test
    fun `Android 12 and older have no page and are never asked to resolve it`() {
        var asked = 0

        assertFalse(AppLocaleSettings.canOpen(32) { asked++; true })
        assertFalse(AppLocaleSettings.canOpen(24) { asked++; true })
        assertFalse(AppLocaleSettings.supported(32))
        assertEquals(0, asked)
    }

    @Test
    fun `Android 13 and later open it only where the intent resolves`() {
        assertTrue(AppLocaleSettings.canOpen(33) { true })
        assertTrue(AppLocaleSettings.canOpen(36) { true })
        assertFalse(AppLocaleSettings.canOpen(33) { false })
        assertTrue(AppLocaleSettings.supported(33))
    }

    @Test
    fun `the action is the platform's`() {
        assertEquals(Settings.ACTION_APP_LOCALE_SETTINGS, AppLocaleSettings.ACTION)
    }
}
