import 'package:material_ui/material_ui.dart';

/// [title] in the surrounding text style with a smaller [hint] under it.
class TitleAndHint extends StatelessWidget {
  const new({required this.title, required this.hint, super.key});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        const SizedBox(height: 2),
        // A disabled tile or menu item would draw it too faint to read.
        Text(
          hint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
