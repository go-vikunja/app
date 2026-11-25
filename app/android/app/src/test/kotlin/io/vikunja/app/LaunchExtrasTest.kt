package io.vikunja.app

import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import org.junit.Assert.assertEquals
import org.junit.Test

class LaunchExtrasTest {
    @Test
    fun `the window is opaque whatever the intent says`() {
        assertEquals(BackgroundMode.opaque, LaunchExtras.backgroundMode)
        val override = MainActivity::class.java.getDeclaredMethod("getBackgroundMode")
        assertEquals(BackgroundMode::class.java, override.returnType)
    }
}
