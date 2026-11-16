package io.vikunja.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PreviousAppTest {
    @Test
    fun `counts only the secure storage entries under its prefix`() {
        val prefix = PreviousApp.SECURE_KEY_PREFIX

        assertEquals(
            2,
            PreviousApp.secureEntryCount(listOf("${prefix}_server-address", "${prefix}_refresh-token", "other", "")),
        )
        assertEquals(0, PreviousApp.secureEntryCount(emptyList()))
    }

    @Test
    fun `finds scheduled notifications unless the stored list is missing or empty`() {
        assertFalse(PreviousApp.hasScheduledNotifications(null))
        assertFalse(PreviousApp.hasScheduledNotifications(""))
        assertFalse(PreviousApp.hasScheduledNotifications("[]"))
        assertFalse(PreviousApp.hasScheduledNotifications(" [ ] "))
        assertTrue(PreviousApp.hasScheduledNotifications("""[{"id":1}]"""))
        assertTrue(PreviousApp.hasScheduledNotifications("not json"))
    }

    @Test
    fun `picks only the background downloader's keys`() {
        assertEquals(
            listOf("com.bbflight.background_downloader.resumeData", "com.bbflight.background_downloader"),
            PreviousApp.downloaderKeys(
                listOf(
                    "com.bbflight.background_downloader.resumeData",
                    "flutter.theme",
                    "com.bbflight.background_downloader",
                    "com.bbflight.other",
                ),
            ),
        )
    }

    @Test
    fun `carries over only the shipped languages`() {
        assertEquals("en", PreviousApp.appLanguage("en"))
        assertEquals("de", PreviousApp.appLanguage("de"))
        assertNull(PreviousApp.appLanguage("de-DE"))
        assertNull(PreviousApp.appLanguage("eo"))
        assertNull(PreviousApp.appLanguage(null))
    }

    @Test
    fun `names what the previous app left`() {
        assertEquals(listOf("update-tasks", "refresh-token", "home_widget_background"), PreviousApp.UNIQUE_WORK)
        assertEquals("BackgroundDownloader", PreviousApp.WORK_TAG)
        assertEquals(listOf("Vikunja1", "Vikunja2"), PreviousApp.CHANNELS)
        assertEquals(listOf("HomeWidgetPreferences", "InternalHomeWidgetPreferences"), PreviousApp.PREFERENCE_FILES)
        assertEquals("com.bbflight.background_downloader", PreviousApp.DOWNLOADER_KEY_PREFIX)
        assertEquals("FlutterSecureStorage", PreviousApp.SECURE_PREFERENCES)
        assertEquals("VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg", PreviousApp.SECURE_KEY_PREFIX)
        assertEquals("scheduled_notifications", PreviousApp.SCHEDULED_NOTIFICATIONS)
    }
}
