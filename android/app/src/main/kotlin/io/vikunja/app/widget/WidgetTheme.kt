package io.vikunja.app.widget

import androidx.compose.ui.graphics.Color
import androidx.glance.color.ColorProvider
import androidx.glance.unit.ColorProvider

/**
 * Theme preference of a single widget instance, persisted by
 * [WidgetConfigureActivity] under `widget_theme_<id>`.
 */
enum class WidgetTheme(val prefName: String) {
    /** Follows the system dark mode. */
    AUTO("auto"),
    LIGHT("light"),
    DARK("dark");

    companion object {
        /** Parses a stored preference value; anything unknown falls back to [AUTO]. */
        fun fromPref(value: String?): WidgetTheme =
            entries.firstOrNull { it.prefName == value } ?: AUTO
    }
}

/**
 * Background opacity preference of a single widget instance (percent 0-100),
 * persisted by [WidgetConfigureActivity] under `widget_opacity_<id>`.
 */
object WidgetOpacity {
    /** Percent backing an absent or corrupt preference: solid, like pre-opacity widgets. */
    const val DEFAULT = 100

    /** Parses a stored preference value; out-of-range values clamp, junk falls back to [DEFAULT]. */
    fun fromPref(value: String?): Int = value?.toIntOrNull()?.coerceIn(0, 100) ?: DEFAULT
}

/**
 * The palette a widget instance renders with: the surfaces and texts the
 * widget paints itself, resolved from the instance's [WidgetTheme].
 *
 * Each role is a day/night pair; forcing a theme pins both sides to the same
 * color so the system dark mode stops mattering, while [WidgetTheme.AUTO] keeps
 * the pair distinct and lets the system resolve (and re-resolve) it.
 *
 * [backgroundOpacityPercent] fades the background roles (surface, title bar)
 * only — texts stay fully opaque. Glance-defaulted controls (row checkboxes,
 * header icon buttons) keep their own system-following colors; the dynamic-color
 * slice rides on this palette.
 */
data class WidgetColors(
    val surface: ColorProvider,
    val text: ColorProvider,
    val titleBarBackground: ColorProvider,
    val titleBarText: ColorProvider,
) {
    companion object {
        private val daySurface = Color.White
        private val nightSurface = Color(0xFF1f2937)
        private val dayText = Color.Black
        private val nightText = Color.White
        private val dayTitleBar = Color(0xFF126cfd)
        private val nightTitleBar = Color(0xFF013992)

        fun forTheme(
            theme: WidgetTheme,
            backgroundOpacityPercent: Int = WidgetOpacity.DEFAULT,
        ): WidgetColors {
            val alpha = backgroundOpacityPercent.coerceIn(0, 100) / 100f
            return when (theme) {
                WidgetTheme.AUTO -> WidgetColors(
                    surface = dayNight(daySurface, nightSurface, alpha),
                    text = dayNight(dayText, nightText),
                    titleBarBackground = dayNight(dayTitleBar, nightTitleBar, alpha),
                    titleBarText = dayNight(dayText, nightText),
                )
                WidgetTheme.LIGHT -> WidgetColors(
                    surface = fixed(daySurface, alpha),
                    text = fixed(dayText),
                    titleBarBackground = fixed(dayTitleBar, alpha),
                    titleBarText = fixed(dayText),
                )
                WidgetTheme.DARK -> WidgetColors(
                    surface = fixed(nightSurface, alpha),
                    text = fixed(nightText),
                    titleBarBackground = fixed(nightTitleBar, alpha),
                    titleBarText = fixed(nightText),
                )
            }
        }

        private fun fixed(color: Color, alpha: Float = 1f) =
            ColorProvider(color.copy(alpha = alpha), color.copy(alpha = alpha))

        private fun dayNight(day: Color, night: Color, alpha: Float = 1f) =
            ColorProvider(day.copy(alpha = alpha), night.copy(alpha = alpha))
    }
}
