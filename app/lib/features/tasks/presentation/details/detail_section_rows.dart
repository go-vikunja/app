import 'package:material_ui/material_ui.dart';

/// A task sheet section's card says it has nothing with this one muted
/// line, where nothing can be added.
class DetailEmptyLine extends StatelessWidget {
  const new({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// "+ Add …", the last row of a task sheet section's card, through which
/// every section adds to itself, and the card's only row while the
/// section is empty, as the attribute card's add line is for an unset
/// property.
class DetailAddRow extends StatelessWidget {
  const new({required this.label, required this.onPressed, super.key});

  final String label;

  /// Null shows it disabled.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    // The button's own padding lines its icon up with the card's text.
    padding: const EdgeInsets.all(4),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add),
        label: Text(label),
      ),
    ),
  );
}
