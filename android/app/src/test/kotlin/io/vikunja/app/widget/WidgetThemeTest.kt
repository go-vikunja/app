package io.vikunja.app.widget

import androidx.compose.ui.graphics.Color
import androidx.glance.color.DayNightColorProvider
import androidx.glance.unit.ColorProvider
import org.junit.Assert.assertEquals
import org.junit.Test

private fun ColorProvider.getColor(isNight: Boolean): Color =
    (this as DayNightColorProvider).getColor(isNight)

class WidgetThemeTest {

    // --- preference parsing ---

    @Test
    fun `null preference resolves to auto`() {
        assertEquals(WidgetTheme.AUTO, WidgetTheme.fromPref(null))
    }

    @Test
    fun `known preference names resolve`() {
        assertEquals(WidgetTheme.AUTO, WidgetTheme.fromPref("auto"))
        assertEquals(WidgetTheme.LIGHT, WidgetTheme.fromPref("light"))
        assertEquals(WidgetTheme.DARK, WidgetTheme.fromPref("dark"))
    }

    @Test
    fun `unknown or corrupt preference falls back to auto`() {
        assertEquals(WidgetTheme.AUTO, WidgetTheme.fromPref(""))
        assertEquals(WidgetTheme.AUTO, WidgetTheme.fromPref("darkk"))
        assertEquals(WidgetTheme.AUTO, WidgetTheme.fromPref("System"))
    }

    @Test
    fun `every theme round-trips through its preference name`() {
        for (theme in WidgetTheme.entries) {
            assertEquals(theme, WidgetTheme.fromPref(theme.prefName))
        }
    }

    // --- palette resolution ---

    private val daySurface = Color.White
    private val nightSurface = Color(0xFF1f2937)
    private val dayText = Color.Black
    private val nightText = Color.White
    private val dayTitleBar = Color(0xFF126cfd)
    private val nightTitleBar = Color(0xFF013992)

    @Test
    fun `auto keeps the day-night pairs so the system theme decides`() {
        val colors = WidgetColors.forTheme(WidgetTheme.AUTO)

        assertEquals(daySurface, colors.surface.getColor(false))
        assertEquals(nightSurface, colors.surface.getColor(true))
        assertEquals(dayText, colors.text.getColor(false))
        assertEquals(nightText, colors.text.getColor(true))
        assertEquals(dayTitleBar, colors.titleBarBackground.getColor(false))
        assertEquals(nightTitleBar, colors.titleBarBackground.getColor(true))
        assertEquals(dayText, colors.titleBarText.getColor(false))
        assertEquals(nightText, colors.titleBarText.getColor(true))
    }

    @Test
    fun `light forces the day palette regardless of system theme`() {
        val colors = WidgetColors.forTheme(WidgetTheme.LIGHT)

        for (isNight in listOf(false, true)) {
            assertEquals(daySurface, colors.surface.getColor(isNight))
            assertEquals(dayText, colors.text.getColor(isNight))
            assertEquals(dayTitleBar, colors.titleBarBackground.getColor(isNight))
            assertEquals(dayText, colors.titleBarText.getColor(isNight))
        }
    }

    @Test
    fun `dark forces the night palette regardless of system theme`() {
        val colors = WidgetColors.forTheme(WidgetTheme.DARK)

        for (isNight in listOf(false, true)) {
            assertEquals(nightSurface, colors.surface.getColor(isNight))
            assertEquals(nightText, colors.text.getColor(isNight))
            assertEquals(nightTitleBar, colors.titleBarBackground.getColor(isNight))
            assertEquals(nightText, colors.titleBarText.getColor(isNight))
        }
    }

    @Test
    fun `surface and text stay readable against each other in every theme`() {
        for (theme in WidgetTheme.entries) {
            val colors = WidgetColors.forTheme(theme)
            for (isNight in listOf(false, true)) {
                assertEquals(
                    "text must contrast with surface in $theme (night=$isNight)",
                    colors.text.getColor(isNight) == Color.White,
                    colors.surface.getColor(isNight) == nightSurface,
                )
            }
        }
    }
}
