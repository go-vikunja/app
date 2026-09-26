import 'package:flutter/material.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_relation.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/widgets/task/relation_kind_ui.dart';

class RelationBadges extends StatelessWidget {
  final Task task;
  final Color textColor;

  const RelationBadges({
    super.key,
    required this.task,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final populated = task.relatedTasks.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList();
    if (populated.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final blocked = task.relatedTasks[RelationKind.blocked] ?? const [];
    final blocking = task.relatedTasks[RelationKind.blocking] ?? const [];

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final entry in populated)
                Tooltip(
                  message: entry.key.label(l10n),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: entry.key.tint.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(entry.key.icon, size: 14, color: textColor),
                        const SizedBox(width: 3),
                        Text(
                          '${entry.value.length}',
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: textColor),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (blocked.isNotEmpty)
            _RelationLine(
              label: l10n.relationKindBlocked,
              tasks: blocked,
              color: textColor,
            ),
          if (blocking.isNotEmpty)
            _RelationLine(
              label: l10n.relationKindBlocking,
              tasks: blocking,
              color: textColor,
            ),
        ],
      ),
    );
  }
}

class _RelationLine extends StatelessWidget {
  final String label;
  final List<Task> tasks;
  final Color color;

  const _RelationLine({
    required this.label,
    required this.tasks,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$label: ${tasks.map((task) => task.title).join(', ')}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

BorderSide relationBorderSide(Task task) {
  final blocked = task.relatedTasks[RelationKind.blocked] ?? const [];
  final blocking = task.relatedTasks[RelationKind.blocking] ?? const [];
  if (blocked.isNotEmpty) {
    return const BorderSide(color: Colors.orange, width: 3);
  }
  if (blocking.isNotEmpty) {
    return const BorderSide(color: Colors.red, width: 3);
  }
  return BorderSide.none;
}
