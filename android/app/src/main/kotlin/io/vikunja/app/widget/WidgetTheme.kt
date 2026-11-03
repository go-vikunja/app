package io.vikunja.app.widget

import android.content.Context
import android.os.Build
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
 * Dynamic-color (Material You) preference of a single widget instance,
 * persisted by [WidgetConfigureActivity] under `widget_dynamic_color_<id>`.
 * When on, the widget paints with the system palette instead of the built-in
 * one — on devices without dynamic color the toggle has no effect and the
 * standard palette is used.
 */
object WidgetDynamicColor {
    /** Parses a stored preference value; anything other than "true" is off. */
    fun fromPref(value: String?): Boolean = value == "true"
}

/**
 * A day/night palette snapshot for the widget's self-painted roles. The
 * built-in Vikunja palette is one instance; a Material You palette read from
 * the system (API 31+) is another.
 */
data class WidgetPalette(
    val daySurface: Color,
    val dayText: Color,
    val dayTitleBar: Color,
    val dayTitleBarText: Color,
    val nightSurface: Color,
    val nightText: Color,
    val nightTitleBar: Color,
    val nightTitleBarText: Color,
)

/**
 * Reads the Material You system palette, mapping the `system_*` accent and
 * neutral ramps onto the widget's roles the way Material 3's dynamic color
 * schemes map them onto `primary`/`onPrimary` and `surface`/`onSurface`.
 */
object WidgetDynamicColors {
    /** Dynamic color needs the Android 12 wallpaper-based palette. */
    fun isSupported(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S

    /**
     * The system palette, or `null` when unavailable — callers fall back to
     * the standard [WidgetColors] palette then.
     */
    fun palette(context: Context): WidgetPalette? {
        if (!isSupported()) return null
        return WidgetPalette(
            daySurface = Color(context.getColor(android.R.color.system_neutral1_50)),
            dayText = Color(context.getColor(android.R.color.system_neutral1_900)),
            dayTitleBar = Color(context.getColor(android.R.color.system_accent1_600)),
            dayTitleBarText = Color(context.getColor(android.R.color.system_accent1_0)),
            nightSurface = Color(context.getColor(android.R.color.system_neutral1_900)),
            nightText = Color(context.getColor(android.R.color.system_neutral1_100)),
            nightTitleBar = Color(context.getColor(android.R.color.system_accent1_200)),
            nightTitleBarText = Color(context.getColor(android.R.color.system_accent1_700)),
        )
    }
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
 * only — texts stay fully opaque. A [dynamicPalette] from
 * [WidgetDynamicColors] replaces the built-in colors role by role; a null one
 * (dynamic color off, or unsupported device) keeps the standard palette.
 * Glance-defaulted controls (row checkboxes, header icon buttons) keep their
 * own system-following colors.
 */
data class WidgetColors(
    val surface: ColorProvider,
    val text: ColorProvider,
    val titleBarBackground: ColorProvider,
    val titleBarText: ColorProvider,
) {
    companion object {
        private val standardPalette = WidgetPalette(
            daySurface = Color.White,
            dayText = Color.Black,
            dayTitleBar = Color(0xFF126cfd),
            dayTitleBarText = Color.Black,
            nightSurface = Color(0xFF1f2937),
            nightText = Color.White,
            nightTitleBar = Color(0xFF013992),
            nightTitleBarText = Color.White,
        )

        fun forTheme(
            theme: WidgetTheme,
            backgroundOpacityPercent: Int = WidgetOpacity.DEFAULT,
            dynamicPalette: WidgetPalette? = null,
        ): WidgetColors {
            val alpha = backgroundOpacityPercent.coerceIn(0, 100) / 100f
            val palette = dynamicPalette ?: standardPalette
            return when (theme) {
                WidgetTheme.AUTO -> WidgetColors(
                    surface = dayNight(palette.daySurface, palette.nightSurface, alpha),
                    text = dayNight(palette.dayText, palette.nightText),
                    titleBarBackground = dayNight(palette.dayTitleBar, palette.nightTitleBar, alpha),
                    titleBarText = dayNight(palette.dayTitleBarText, palette.nightTitleBarText),
                )
                WidgetTheme.LIGHT -> WidgetColors(
                    surface = fixed(palette.daySurface, alpha),
                    text = fixed(palette.dayText),
                    titleBarBackground = fixed(palette.dayTitleBar, alpha),
                    titleBarText = fixed(palette.dayTitleBarText),
                )
                WidgetTheme.DARK -> WidgetColors(
                    surface = fixed(palette.nightSurface, alpha),
                    text = fixed(palette.nightText),
                    titleBarBackground = fixed(palette.nightTitleBar, alpha),
                    titleBarText = fixed(palette.nightTitleBarText),
                )
            }
        }

        private fun fixed(color: Color, alpha: Float = 1f) =
            ColorProvider(color.copy(alpha = alpha), color.copy(alpha = alpha))

        private fun dayNight(day: Color, night: Color, alpha: Float = 1f) =
            ColorProvider(day.copy(alpha = alpha), night.copy(alpha = alpha))
    }
}
