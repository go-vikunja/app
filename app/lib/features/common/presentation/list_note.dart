import 'package:material_ui/material_ui.dart';

/// A quiet line above a list that says what the list shows.
class ListNote extends StatelessWidget {
  const new({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      container: true,
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(icon, size: 20, color: colors.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [notes] stacked, for the header of a list or of its empty state; null
/// without any.
Widget? stackedNotes(List<Widget> notes) => switch (notes) {
  [] => null,
  [final note] => note,
  _ => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < notes.length; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        notes[i],
      ],
    ],
  ),
};
