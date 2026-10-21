import 'package:material_ui/material_ui.dart';

/// A small pill with a count, "3" or "3/5" with a [limit]; in the error
/// colours when [alert], by default once the count is over the limit.
class CountBadge extends StatelessWidget {
  const new({
    required this.count,
    this.limit,
    bool? alert,
    this.semanticsLabel,
    super.key,
  }) : alert = alert ?? (limit != null && count > limit);

  final int count;
  final int? limit;
  final bool alert;

  /// What a screen reader says instead of the bare numbers.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (background, foreground) = alert
        ? (colors.error, colors.onError)
        : (colors.secondaryContainer, colors.onSecondaryContainer);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: background,
          shape: const StadiumBorder(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            switch (limit) {
              null => '$count',
              final limit => '$count/$limit',
            },
            textAlign: TextAlign.center,
            semanticsLabel: semanticsLabel,
            style: theme.textTheme.labelSmall?.copyWith(color: foreground),
          ),
        ),
      ),
    );
  }
}
