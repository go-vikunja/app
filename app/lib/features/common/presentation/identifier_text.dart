import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';

/// A task's identifier such as `WORK-12`, small, muted and monospaced.
class IdentifierText extends StatelessWidget {
  const new(this.identifier, {this.style, super.key});

  final String identifier;

  /// Merged over the default 12 sp muted style.
  final TextStyle? style;

  /// The width [identifier] takes in the default style and the current
  /// text scale.
  static double widthOf(BuildContext context, String identifier) {
    final painter = TextPainter(
      text: TextSpan(text: identifier, style: _style(context, null)),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  static TextStyle? _style(BuildContext context, TextStyle? style) {
    final theme = Theme.of(context);
    return theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)
        .merge(AppTheme.monospace)
        .merge(style);
  }

  @override
  Widget build(BuildContext context) =>
      Text(identifier, style: _style(context, style));
}
