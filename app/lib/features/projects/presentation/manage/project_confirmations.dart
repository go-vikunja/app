import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_dialog_action.dart';
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';

/// The web's questions before archiving and unarchiving, naming the
/// user's [defaultProject] when it is archived along.
Future<bool> confirmArchiveProject(
  BuildContext context, {
  required bool archive,
  String? defaultProject,
}) {
  final l10n = context.l10n;
  return confirmAdaptive(
    context,
    title: archive ? l10n.projectArchiveTitle : l10n.projectUnarchiveTitle,
    body: [
      if (archive) l10n.projectArchiveBody else l10n.projectUnarchiveBody,
      if (defaultProject != null) l10n.projectIncludesDefault(defaultProject),
    ].join('\n\n'),
    confirmLabel: archive ? l10n.projectArchive : l10n.projectUnarchive,
  );
}

/// Names the project and everything the server deletes with it: the tasks
/// of the project and of every project below it, and the user's
/// [defaultProject] when it is one of them; without a [taskCount] (the
/// tasks could not be counted) it says so in general.
Future<bool> confirmDeleteProject(
  BuildContext context, {
  required String project,
  required int? taskCount,
  required int subprojectCount,
  String? defaultProject,
}) {
  final l10n = context.l10n;
  return confirmAdaptive(
    context,
    title: l10n.projectDeleteTitle(project),
    body: [
      switch (taskCount) {
        null => l10n.projectDeleteEverything,
        final tasks when subprojectCount > 0 =>
          l10n.projectDeleteTasksAndSubprojects(tasks, subprojectCount),
        final tasks => l10n.projectDeleteTasks(tasks),
      },
      if (defaultProject != null) l10n.projectIncludesDefault(defaultProject),
      l10n.projectDeleteCannotBeUndone,
    ].join('\n\n'),
    confirmLabel: l10n.projectDelete,
    destructive: true,
  );
}

Future<bool> confirmDeleteView(BuildContext context, {required String view}) {
  final l10n = context.l10n;
  return confirmAdaptive(
    context,
    title: l10n.projectViewDeleteTitle(view),
    body: l10n.projectViewDeleteBody,
    confirmLabel: l10n.projectViewDelete,
    destructive: true,
  );
}

/// True when the user chooses to drop the unsaved edits of a project.
Future<bool> confirmDiscardProjectChanges(BuildContext context) async {
  final l10n = context.l10n;
  final discard = await showAdaptiveDialog<bool>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      scrollable: true,
      title: Text(l10n.taskEditDiscardTitle),
      content: Text(l10n.projectEditDiscardBody),
      actions: [
        AdaptiveDialogAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.taskEditKeepEditing),
        ),
        AdaptiveDialogAction(
          onPressed: () => Navigator.of(context).pop(true),
          isDestructive: true,
          child: Text(l10n.taskEditDiscard),
        ),
      ],
    ),
  );
  return discard ?? false;
}
