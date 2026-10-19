import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_format.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';

/// The web's footer: "Created 2 days ago by Anna", "Updated 1 hour ago"
/// when that differs, "Done 5 minutes ago" once done; screen readers get
/// the dates themselves.
class TaskMetadataLine extends ConsumerWidget {
  const new({required this.task, super.key});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final now = ref.watch(clockTickProvider);
    String relative(DateTime moment) =>
        formatRelativeTime(l10n, moment, now: now);
    String absolute(DateTime moment) => formatMoment(context, moment);
    final creator = task.createdBy?.displayName ?? '';
    String createdAt(String when) => creator.isEmpty
        ? l10n.taskDetailCreated(when)
        : l10n.taskDetailCreatedBy(when, creator);
    final lines = <(String, String)>[
      if (task.created case final created?)
        (createdAt(relative(created)), createdAt(absolute(created))),
      if (task.updated case final updated?
          when task.created == null ||
              updated.millisecondsSinceEpoch !=
                  task.created!.millisecondsSinceEpoch)
        (
          l10n.taskDetailUpdated(relative(updated)),
          l10n.taskDetailUpdated(absolute(updated)),
        ),
      if (task.doneAt case final doneAt? when task.done)
        (
          l10n.taskDetailDoneWhen(relative(doneAt)),
          l10n.taskDetailDoneWhen(absolute(doneAt)),
        ),
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        for (final (text, label) in lines)
          Semantics(
            container: true,
            label: label,
            excludeSemantics: true,
            child: Text(text, style: style),
          ),
      ],
    );
  }
}
