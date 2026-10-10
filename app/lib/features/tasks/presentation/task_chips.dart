import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';

class LabelChip extends StatelessWidget {
  const new({required this.label, super.key});

  final Label label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = parseHexColor(label.hexColor);
    return _Chip(
      background: background ?? colors.surfaceContainerHighest,
      foreground: background == null
          ? colors.onSurface
          : contrastingTextColor(background),
      text: label.title,
      semanticsLabel: context.l10n.labelSemantics(label.title),
    );
  }
}

/// Only for high, urgent and do-now, like the web's list rows.
class PriorityChip extends StatelessWidget {
  const new({required this.priority, super.key});

  final TaskPriority priority;

  static bool shows(TaskPriority priority) =>
      priority.value >= TaskPriority.high.value;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final urgent = priority.value >= TaskPriority.urgent.value;
    final text = priorityLabel(l10n, priority);
    return _Chip(
      background: urgent ? colors.errorContainer : colors.tertiaryContainer,
      foreground: urgent ? colors.onErrorContainer : colors.onTertiaryContainer,
      icon: Icons.priority_high,
      text: text,
      semanticsLabel: l10n.prioritySemantics(text),
    );
  }
}

class _Chip extends StatelessWidget {
  const new({
    required this.background,
    required this.foreground,
    required this.text,
    required this.semanticsLabel,
    this.icon,
  });

  final Color background;
  final Color foreground;
  final String text;
  final String semanticsLabel;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: foreground);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon case final icon?) ...[
              ExcludeSemantics(child: Icon(icon, size: 14, color: foreground)),
              const SizedBox(width: 2),
            ],
            Flexible(
              child: Text(
                text,
                style: style,
                semanticsLabel: semanticsLabel,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
