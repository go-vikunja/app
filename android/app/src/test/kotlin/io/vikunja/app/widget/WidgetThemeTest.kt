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

    // --- dynamic color (Material You) ---

    /** Distinct color per role and side, so every mapping assertion is unambiguous. */
    private fun fakeDynamicPalette() = WidgetPalette(
        daySurface = Color(0xFF010203),
        dayText = Color(0xFF040506),
        dayTitleBar = Color(0xFF070809),
        dayTitleBarText = Color(0xFF0a0b0c),
        nightSurface = Color(0xFF0d0e0f),
        nightText = Color(0xFF101112),
        nightTitleBar = Color(0xFF131415),
        nightTitleBarText = Color(0xFF161718),
    )

    @Test
    fun `null dynamic-color preference resolves to off`() {
        assertEquals(false, WidgetDynamicColor.fromPref(null))
    }

    @Test
    fun `dynamic-color preference parses true and false`() {
        assertEquals(true, WidgetDynamicColor.fromPref("true"))
        assertEquals(false, WidgetDynamicColor.fromPref("false"))
    }

    @Test
    fun `unknown or corrupt dynamic-color preference falls back to off`() {
        assertEquals(false, WidgetDynamicColor.fromPref(""))
        assertEquals(false, WidgetDynamicColor.fromPref("True"))
        assertEquals(false, WidgetDynamicColor.fromPref("1"))
        assertEquals(false, WidgetDynamicColor.fromPref("yes"))
    }

    @Test
    fun `absent dynamic palette keeps the standard palette in every theme`() {
        for (theme in WidgetTheme.entries) {
            assertEquals(
                WidgetColors.forTheme(theme),
                WidgetColors.forTheme(theme, dynamicPalette = null),
            )
        }
    }

    @Test
    fun `dynamic palette overrides every role in auto theme`() {
        val dyn = fakeDynamicPalette()
        val colors = WidgetColors.forTheme(WidgetTheme.AUTO, dynamicPalette = dyn)

        assertEquals(dyn.daySurface, colors.surface.getColor(false))
        assertEquals(dyn.nightSurface, colors.surface.getColor(true))
        assertEquals(dyn.dayText, colors.text.getColor(false))
        assertEquals(dyn.nightText, colors.text.getColor(true))
        assertEquals(dyn.dayTitleBar, colors.titleBarBackground.getColor(false))
        assertEquals(dyn.nightTitleBar, colors.titleBarBackground.getColor(true))
        assertEquals(dyn.dayTitleBarText, colors.titleBarText.getColor(false))
        assertEquals(dyn.nightTitleBarText, colors.titleBarText.getColor(true))
    }

    @Test
    fun `light theme pins the dynamic day palette regardless of system theme`() {
        val dyn = fakeDynamicPalette()
        val colors = WidgetColors.forTheme(WidgetTheme.LIGHT, dynamicPalette = dyn)

        for (isNight in listOf(false, true)) {
            assertEquals(dyn.daySurface, colors.surface.getColor(isNight))
            assertEquals(dyn.dayText, colors.text.getColor(isNight))
            assertEquals(dyn.dayTitleBar, colors.titleBarBackground.getColor(isNight))
            assertEquals(dyn.dayTitleBarText, colors.titleBarText.getColor(isNight))
        }
    }

    @Test
    fun `dark theme pins the dynamic night palette regardless of system theme`() {
        val dyn = fakeDynamicPalette()
        val colors = WidgetColors.forTheme(WidgetTheme.DARK, dynamicPalette = dyn)

        for (isNight in listOf(false, true)) {
            assertEquals(dyn.nightSurface, colors.surface.getColor(isNight))
            assertEquals(dyn.nightText, colors.text.getColor(isNight))
            assertEquals(dyn.nightTitleBar, colors.titleBarBackground.getColor(isNight))
            assertEquals(dyn.nightTitleBarText, colors.titleBarText.getColor(isNight))
        }
    }

    @Test
    fun `opacity fades dynamic backgrounds but keeps dynamic texts opaque`() {
        val dyn = fakeDynamicPalette()
        for (theme in WidgetTheme.entries) {
            val colors = WidgetColors.forTheme(theme, backgroundOpacityPercent = 0, dynamicPalette = dyn)
            for (isNight in listOf(false, true)) {
                assertEquals(0f, colors.surface.getColor(isNight).alpha)
                assertEquals(0f, colors.titleBarBackground.getColor(isNight).alpha)
                assertEquals(1f, colors.text.getColor(isNight).alpha)
                assertEquals(1f, colors.titleBarText.getColor(isNight).alpha)
            }
        }
    }

    @Test
    fun `mid opacity halves dynamic background alpha without touching the colors`() {
        val dyn = fakeDynamicPalette()
        val colors = WidgetColors.forTheme(WidgetTheme.AUTO, backgroundOpacityPercent = 50, dynamicPalette = dyn)

        assertEquals(dyn.daySurface.copy(alpha = 0.5f), colors.surface.getColor(false))
        assertEquals(dyn.nightSurface.copy(alpha = 0.5f), colors.surface.getColor(true))
        assertEquals(dyn.dayTitleBar.copy(alpha = 0.5f), colors.titleBarBackground.getColor(false))
        assertEquals(dyn.nightTitleBar.copy(alpha = 0.5f), colors.titleBarBackground.getColor(true))
        assertEquals(dyn.dayText, colors.text.getColor(false))
        assertEquals(dyn.nightText, colors.text.getColor(true))
    }
}
