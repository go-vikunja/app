import 'package:material_ui/material_ui.dart';

/// A name's initials in a circle that does not grow with the text; only
/// decoration, the name is next to it or in the enclosing button's label.
/// [primary] colours mark the user's own accounts, the secondary ones
/// other people.
class InitialsAvatar extends StatelessWidget {
  const new({
    required this.name,
    this.radius = 14,
    this.primary = false,
    super.key,
  });

  final String name;
  final double radius;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (background, foreground) = primary
        ? (colors.primaryContainer, colors.onPrimaryContainer)
        : (colors.secondaryContainer, colors.onSecondaryContainer);
    final style = switch (radius) {
      >= 30 => theme.textTheme.headlineSmall,
      >= 20 => theme.textTheme.titleSmall,
      > 12 => theme.textTheme.labelMedium,
      _ => theme.textTheme.labelSmall?.copyWith(fontSize: 10),
    };
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: background,
        child: Text(
          initialsOf(name),
          style: style?.copyWith(color: foreground),
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }
}

String initialsOf(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  final first = words.first.characters.first;
  final last = words.length > 1 ? words.last.characters.first : '';
  return (first + last).toUpperCase();
}
