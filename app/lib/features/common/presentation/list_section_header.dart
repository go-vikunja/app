import 'package:material_ui/material_ui.dart';

class ListSectionHeader extends StatelessWidget {
  const new({required this.title, this.count, super.key});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.primary,
                ),
              ),
            ),
            if (count case final count?)
              Text(
                '$count',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
