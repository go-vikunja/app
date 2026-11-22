import 'package:material_ui/material_ui.dart';

/// A muted label with its icon over the group it names, as the New task
/// sheet and the edit page head their fields, and a short [note] on the
/// group after it, on the next line when there is no room beside it.
class TaskFormHeading extends StatelessWidget {
  const new({
    required this.icon,
    required this.text,
    this.note,
    this.top = 6,
    this.bottom = 2,
    super.key,
  });

  final IconData icon;
  final String text;
  final String? note;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top, 16, bottom),
      child: Wrap(
        spacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Semantics(
            header: true,
            headingLevel: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    style: theme.textTheme.labelMedium?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
          if (note case final note?)
            Text(
              note,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
        ],
      ),
    );
  }
}

/// One line of chips that scrolls sideways.
class ChipRow extends StatelessWidget {
  const new({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        for (final child in children) ...[child, const SizedBox(width: 8)],
      ],
    ),
  );
}
