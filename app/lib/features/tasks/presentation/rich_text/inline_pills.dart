import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/features/common/presentation/user_avatar.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/tasks/application/task_providers.dart';

/// A mentioned user: avatar and name.
class MentionPill extends StatelessWidget {
  const new({
    required this.username,
    required this.label,
    required this.style,
    super.key,
  });

  final String username;
  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = label.isNotEmpty ? label : username;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(2, 1, 8, 1),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar(
            user: User(id: 0, username: username, name: name),
            radius: 9,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              name,
              style: style.copyWith(color: colors.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// A link to a task of the account, as the web upgrades it: the local
/// task's project (when it is not the current one) and title, checked and
/// struck through once done; the href while the task is not on this device,
/// which a tap still tries to open.
class TaskLinkPill extends ConsumerWidget {
  const new({
    required this.taskId,
    required this.href,
    required this.style,
    required this.onOpen,
    this.projectId,
    super.key,
  });

  final int taskId;
  final String href;
  final TextStyle style;
  final VoidCallback onOpen;
  final int? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final task = ref.watch(taskByIdProvider(taskId)).value;
    final project = task == null
        ? null
        : ref.watch(projectByIdProvider(task.projectId));
    final String text;
    final String semanticsLabel;
    if (task == null) {
      text = href;
      semanticsLabel = href;
    } else {
      final prefix = task.projectId != projectId && project != null
          ? '${project.displayTitle(l10n)} › '
          : '';
      text = '$prefix${task.title}';
      semanticsLabel = task.done ? '$text, ${l10n.taskDoneSemantics}' : text;
    }
    final done = task?.done ?? false;
    final foreground = done ? colors.onSurfaceVariant : colors.primary;
    return Semantics(
      link: true,
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: onOpen,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (done) ...[
                  Icon(Icons.done_all, size: 16, color: foreground),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    text,
                    style: style.copyWith(
                      color: foreground,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
