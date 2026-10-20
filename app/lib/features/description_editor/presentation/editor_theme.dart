import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/features/description_editor/application/editor_protocol.dart';

/// The page's colours from the app's colour scheme, close to the tokens
/// the native rich text uses, so editing looks like reading; `outline`
/// also colours the placeholder, so it takes the stronger outline token.
/// And the text scale the app applies.
EditorTheme editorThemeOf(BuildContext context) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;
  return EditorTheme(
    dark: theme.brightness == Brightness.dark,
    colors: {
      'text': cssColor(colors.onSurface),
      'background': cssColor(colors.surface),
      'primary': cssColor(colors.primary),
      'outline': cssColor(colors.outline),
      'surface': cssColor(colors.surfaceContainerHigh),
      'error': cssColor(colors.error),
      'selection': cssColor(colors.primary.withValues(alpha: 0.3)),
      'link': cssColor(colors.primary),
      'codeBackground': cssColor(colors.surfaceContainerHighest),
    },
    fontScale: MediaQuery.textScalerOf(context).scale(16) / 16,
  );
}

String cssColor(Color color) {
  int channel(double value) => (value * 255).round().clamp(0, 255);
  final (r, g, b) = (channel(color.r), channel(color.g), channel(color.b));
  String hex(int channel) => channel.toRadixString(16).padLeft(2, '0');
  if (color.a >= 1) return '#${hex(r)}${hex(g)}${hex(b)}';
  return 'rgba($r, $g, $b, ${color.a.toStringAsFixed(3)})';
}
