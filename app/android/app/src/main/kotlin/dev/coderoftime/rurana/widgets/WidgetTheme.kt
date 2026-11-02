package dev.coderoftime.rurana.widgets

import android.os.Build
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.glance.GlanceTheme
import androidx.glance.color.ColorProvider
import androidx.glance.color.colorProviders

// AppTheme.brandScheme (app/lib/app/theme/app_theme.dart), light and dark:
// the blue tonal scheme with the amber tertiary of D56.
private val brandColors = colorProviders(
    primary = ColorProvider(day = Color(0xFF0058CC), night = Color(0xFFB0C6FF)),
    onPrimary = ColorProvider(day = Color(0xFFFFFFFF), night = Color(0xFF002C6F)),
    primaryContainer = ColorProvider(day = Color(0xFFD9E2FF), night = Color(0xFF00419C)),
    onPrimaryContainer = ColorProvider(day = Color(0xFF00419C), night = Color(0xFFD9E2FF)),
    secondary = ColorProvider(day = Color(0xFF575E71), night = Color(0xFFC0C6DC)),
    onSecondary = ColorProvider(day = Color(0xFFFFFFFF), night = Color(0xFF293042)),
    secondaryContainer = ColorProvider(day = Color(0xFFDCE2F9), night = Color(0xFF404659)),
    onSecondaryContainer = ColorProvider(day = Color(0xFF404659), night = Color(0xFFDCE2F9)),
    tertiary = ColorProvider(day = Color(0xFF815500), night = Color(0xFFFFD08E)),
    onTertiary = ColorProvider(day = Color(0xFFFFFFFF), night = Color(0xFF442B00)),
    tertiaryContainer = ColorProvider(day = Color(0xFFF5AE39), night = Color(0xFFF5AE39)),
    onTertiaryContainer = ColorProvider(day = Color(0xFF684400), night = Color(0xFF684400)),
    error = ColorProvider(day = Color(0xFFBA1A1A), night = Color(0xFFFFB4AB)),
    errorContainer = ColorProvider(day = Color(0xFFFFDAD6), night = Color(0xFF93000A)),
    onError = ColorProvider(day = Color(0xFFFFFFFF), night = Color(0xFF690005)),
    onErrorContainer = ColorProvider(day = Color(0xFF93000A), night = Color(0xFFFFDAD6)),
    background = ColorProvider(day = Color(0xFFF8F9FF), night = Color(0xFF0E141C)),
    onBackground = ColorProvider(day = Color(0xFF161C24), night = Color(0xFFDDE3EE)),
    surface = ColorProvider(day = Color(0xFFF8F9FF), night = Color(0xFF0E141C)),
    onSurface = ColorProvider(day = Color(0xFF161C24), night = Color(0xFFDDE3EE)),
    surfaceVariant = ColorProvider(day = Color(0xFFDDE3EE), night = Color(0xFF2F353E)),
    onSurfaceVariant = ColorProvider(day = Color(0xFF3F4753), night = Color(0xFFBFC7D5)),
    outline = ColorProvider(day = Color(0xFF6F7884), night = Color(0xFF89919E)),
    inverseOnSurface = ColorProvider(day = Color(0xFFEBF1FD), night = Color(0xFF2B3139)),
    inverseSurface = ColorProvider(day = Color(0xFF2B3139), night = Color(0xFFDDE3EE)),
    inversePrimary = ColorProvider(day = Color(0xFFB0C6FF), night = Color(0xFF0058CC)),
    widgetBackground = ColorProvider(day = Color(0xFFF8F9FF), night = Color(0xFF0E141C)),
)

// Whether the widget draws in the system palette: Glance refuses its
// resource-backed colours as explicit checkbox colours.
internal val LocalSystemPalette = staticCompositionLocalOf { false }

// The system palette on Android 12+ unless "Use system colours" is off in
// the app (D45); the brand scheme otherwise.
@Composable
internal fun WidgetTheme(dynamicColor: Boolean, content: @Composable () -> Unit) {
    val dynamic = dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
    CompositionLocalProvider(LocalSystemPalette provides dynamic) {
        GlanceTheme(colors = if (dynamic) GlanceTheme.colors else brandColors, content = content)
    }
}
