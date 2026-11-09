import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/project_icon.dart';
import 'package:vikunja_mobile/features/tasks/application/account_context_providers.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';

/// A task in the bin: its title, its project when this device has it, who
/// moved it there when, and how long the server keeps it. Not tappable: a
/// trashed task cannot be opened.
class TrashTaskRow extends StatelessWidget {
  const new({
    required this.item,
    required this.project,
    required this.busy,
    required this.enabled,
    required this.onRestore,
    required this.onDeleteForever,
    super.key,
  });

  final TrashedTask item;

  /// The task's project as stored on this device; null when it is not.
  final Project? project;

  /// An action of this row is on its way.
  final bool busy;

  /// False while any action of the page is on its way.
  final bool enabled;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = trashItemTitle(item.task.title);
    final project = this.project;
    return _TrashRow(
      title: title,
      lines: [
        if (project != null) Text(project.displayTitle(l10n)),
        TrashDeletedLines(deletedAt: item.deletedAt, deletedBy: item.deletedBy),
      ],
      actions: _RowActions(
        title: title,
        busy: busy,
        enabled: enabled,
        onRestore: onRestore,
        onDeleteForever: item.canDeletePermanently ? onDeleteForever : null,
      ),
    );
  }
}

/// A project in the bin with the subprojects that went there with it, who
/// moved it there when, and how long the server keeps it.
class TrashProjectRow extends StatelessWidget {
  const new({
    required this.item,
    required this.busy,
    required this.enabled,
    required this.onRestore,
    required this.onDeleteForever,
    super.key,
  });

  final TrashedProject item;

  /// An action of this row is on its way.
  final bool busy;

  /// False while any action of the page is on its way.
  final bool enabled;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final project = item.project;
    final title = trashItemTitle(project.displayTitle(l10n));
    final subprojects = item.subprojects;
    return _TrashRow(
      leading: ProjectIcon(hexColor: project.hexColor),
      title: title,
      lines: [
        if (subprojects.isNotEmpty)
          Text(
            l10n.trashSubprojects(
              subprojects.length,
              [
                for (final subproject in subprojects)
                  trashItemTitle(
                    projectDisplayTitle(
                      l10n,
                      subproject.title,
                      projectId: subproject.id,
                    ),
                  ),
              ].join(', '),
            ),
          ),
        TrashDeletedLines(deletedAt: item.deletedAt, deletedBy: item.deletedBy),
      ],
      actions: _RowActions(
        title: title,
        busy: busy,
        enabled: enabled,
        onRestore: onRestore,
        onDeleteForever: onDeleteForever,
      ),
    );
  }
}

/// A row of the bin: [actions] trail the texts, and go below [lines] at
/// large text, which keeps the texts the row's width.
class _TrashRow extends StatelessWidget {
  const new({
    required this.title,
    required this.lines,
    required this.actions,
    this.leading,
  });

  final Widget? leading;
  final String title;
  final List<Widget> lines;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(10) > 13;
    return ListTile(
      leading: leading,
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [...lines, if (largeText) actions],
      ),
      trailing: largeText ? null : actions,
    );
  }
}

/// [title], or a dash when it is blank.
String trashItemTitle(String title) => title.trim().isEmpty ? '–' : title;

/// "Deleted 3 days ago by Kim" and "Deleted forever in 27 days"; screen
/// readers hear the date of the deletion itself.
class TrashDeletedLines extends ConsumerWidget {
  const new({required this.deletedAt, required this.deletedBy, super.key});

  final DateTime deletedAt;

  /// Null when the server names nobody; a link share has a negative id.
  final User? deletedBy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = ref.watch(clockTickProvider);
    final formatter = MomentFormatter.watch(context, ref);
    final userId = ref.watch(activeUserIdProvider);
    String deleted(String when) => switch (deletedBy) {
      null => l10n.trashDeletedWhen(when),
      User(:final id) when id == userId => l10n.trashDeletedByYou(when),
      User(:final id) when id < 0 => l10n.trashDeletedByLinkShare(when),
      final user => l10n.trashDeletedBy(when, user.displayName),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          label: deleted(formatter.spokenAbsolute(deletedAt)),
          excludeSemantics: true,
          child: Text(deleted(formatter.relative(deletedAt, now: now))),
        ),
        Text(l10n.trashDeletedForGoodIn(trashDaysLeft(deletedAt, now: now))),
      ],
    );
  }
}

/// Restore and, when [onDeleteForever] is set, Delete forever; a spinner
/// in their place while [busy].
class _RowActions extends StatelessWidget {
  const new({
    required this.title,
    required this.busy,
    required this.enabled,
    required this.onRestore,
    required this.onDeleteForever,
  });

  final String title;
  final bool busy;
  final bool enabled;
  final VoidCallback onRestore;
  final VoidCallback? onDeleteForever;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onDeleteForever = this.onDeleteForever;
    if (busy) {
      // As wide as the buttons, so that the title does not reflow.
      return SizedBox(
        width: (onDeleteForever == null ? 1 : 2) * kMinInteractiveDimension,
        height: kMinInteractiveDimension,
        child: Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              semanticsLabel: l10n.trashWorking,
            ),
          ),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: enabled ? onRestore : null,
          tooltip: l10n.trashRestoreItem(title),
          icon: const Icon(Icons.restore_from_trash_outlined),
        ),
        if (onDeleteForever != null)
          IconButton(
            onPressed: enabled ? onDeleteForever : null,
            tooltip: l10n.trashDeleteForeverItem(title),
            color: Theme.of(context).colorScheme.error,
            icon: const Icon(Icons.delete_forever_outlined),
          ),
      ],
    );
  }
}
