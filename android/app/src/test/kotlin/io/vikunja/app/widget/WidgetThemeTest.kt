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

    // --- opacity preference parsing ---

    @Test
    fun `null opacity preference resolves to fully opaque`() {
        assertEquals(100, WidgetOpacity.fromPref(null))
    }

    @Test
    fun `opacity preference round-trips the whole range`() {
        for (percent in listOf(0, 1, 50, 99, 100)) {
            assertEquals(percent, WidgetOpacity.fromPref(percent.toString()))
        }
    }

    @Test
    fun `out-of-range opacity preference is clamped`() {
        assertEquals(0, WidgetOpacity.fromPref("-1"))
        assertEquals(0, WidgetOpacity.fromPref("-100"))
        assertEquals(100, WidgetOpacity.fromPref("101"))
        assertEquals(100, WidgetOpacity.fromPref("1000"))
    }

    @Test
    fun `unknown or corrupt opacity preference falls back to fully opaque`() {
        assertEquals(100, WidgetOpacity.fromPref(""))
        assertEquals(100, WidgetOpacity.fromPref("transparent"))
        assertEquals(100, WidgetOpacity.fromPref("50%"))
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

    // --- background opacity ---

    @Test
    fun `zero opacity makes every background fully transparent in every theme`() {
        for (theme in WidgetTheme.entries) {
            val colors = WidgetColors.forTheme(theme, backgroundOpacityPercent = 0)
            for (isNight in listOf(false, true)) {
                assertEquals(0f, colors.surface.getColor(isNight).alpha)
                assertEquals(0f, colors.titleBarBackground.getColor(isNight).alpha)
            }
        }
    }

    @Test
    fun `zero opacity keeps every text fully opaque`() {
        for (theme in WidgetTheme.entries) {
            val colors = WidgetColors.forTheme(theme, backgroundOpacityPercent = 0)
            for (isNight in listOf(false, true)) {
                assertEquals(1f, colors.text.getColor(isNight).alpha)
                assertEquals(1f, colors.titleBarText.getColor(isNight).alpha)
            }
        }
    }

    @Test
    fun `mid opacity halves background alpha in auto theme`() {
        val colors = WidgetColors.forTheme(WidgetTheme.AUTO, backgroundOpacityPercent = 50)

        assertEquals(daySurface.copy(alpha = 0.5f), colors.surface.getColor(false))
        assertEquals(nightSurface.copy(alpha = 0.5f), colors.surface.getColor(true))
        assertEquals(dayTitleBar.copy(alpha = 0.5f), colors.titleBarBackground.getColor(false))
        assertEquals(nightTitleBar.copy(alpha = 0.5f), colors.titleBarBackground.getColor(true))
    }

    @Test
    fun `forced themes fade their pinned background color on both sides`() {
        val light = WidgetColors.forTheme(WidgetTheme.LIGHT, backgroundOpacityPercent = 50)
        val dark = WidgetColors.forTheme(WidgetTheme.DARK, backgroundOpacityPercent = 50)

        for (isNight in listOf(false, true)) {
            assertEquals(daySurface.copy(alpha = 0.5f), light.surface.getColor(isNight))
            assertEquals(nightSurface.copy(alpha = 0.5f), dark.surface.getColor(isNight))
        }
    }

    @Test
    fun `full opacity resolves the same palette as the default`() {
        for (theme in WidgetTheme.entries) {
            assertEquals(
                WidgetColors.forTheme(theme),
                WidgetColors.forTheme(theme, backgroundOpacityPercent = 100),
            )
        }
    }

    @Test
    fun `out-of-range opacity is clamped`() {
        assertEquals(
            0f,
            WidgetColors
                .forTheme(WidgetTheme.AUTO, backgroundOpacityPercent = -10)
                .surface
                .getColor(false)
                .alpha,
        )
        assertEquals(
            1f,
            WidgetColors
                .forTheme(WidgetTheme.AUTO, backgroundOpacityPercent = 150)
                .surface
                .getColor(false)
                .alpha,
        )
    }
}
