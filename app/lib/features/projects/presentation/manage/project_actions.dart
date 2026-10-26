import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/router/pop_pages_over_shell.dart';
import 'package:vikunja_mobile/core/repositories/project_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/settings/user_settings_providers.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/features/projects/application/project_management.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/duplicate_project_sheet.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/form_parts.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/new_project_sheet.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_change_failure.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_confirmations.dart';

final _log = Logger('ProjectActions');

/// The project menu's actions, each online: one at a time, said in a
/// snackbar once the server took it, or why it did not.
mixin ProjectManagementActions<W extends ConsumerStatefulWidget>
    on ConsumerState<W> {
  var _managing = false;

  /// A change of the project is on its way.
  bool get managingProject => _managing;

  Future<bool> _send(
    ProjectChange change,
    Project project, {
    required String done,
    required Future<void> Function(ProjectRepository repository) send,
  }) async {
    final repository = ref.read(projectRepositoryProvider);
    if (repository == null || _managing) return false;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _managing = true);
    try {
      await send(repository);
      unawaited(HapticFeedback.selectionClick());
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(done)));
      return true;
    } on Object catch (error) {
      _log.warning('Changing a project failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              projectChangeFailureText(
                l10n,
                error,
                change,
                titleTooLong:
                    project.title.trim().runes.length > projectTitleMaxLength,
              ),
            ),
          ),
        );
      return false;
    } finally {
      if (mounted) setState(() => _managing = false);
    }
  }

  void editProject(Project project) =>
      unawaited(GoRouter.of(context).push(AppRoutes.projectEdit(project.id)));

  void openProjectViews(Project project) =>
      unawaited(GoRouter.of(context).push(AppRoutes.projectViews(project.id)));

  void openProjectShare(Project project) =>
      unawaited(GoRouter.of(context).push(AppRoutes.projectShare(project.id)));

  Future<void> duplicateProject(Project project) =>
      duplicateProjectAndOpen(context, project: project);

  Future<void> createSubproject(Project project) =>
      createProjectAndOpen(context, parentProjectId: project.id);

  Future<void> toggleProjectFavourite(Project project) {
    final l10n = context.l10n;
    final favourite = !project.isFavorite;
    return _send(
      ProjectChange.favourite,
      project,
      done: favourite ? l10n.projectFavourited : l10n.projectUnfavourited,
      send: (repository) => repository.updateProject(
        project.id,
        ProjectChanges(isFavorite: favourite),
      ),
    );
  }

  Future<void> setProjectArchived(
    Project project, {
    required bool archived,
  }) async {
    final l10n = context.l10n;
    final defaultProject = archived ? _defaultProjectBelow(project.id) : null;
    if (!await confirmArchiveProject(
          context,
          archive: archived,
          defaultProject: defaultProject?.displayTitle(l10n),
        ) ||
        !mounted) {
      return;
    }
    await _send(
      archived ? ProjectChange.archive : ProjectChange.unarchive,
      project,
      done: archived ? l10n.projectArchivedDone : l10n.projectUnarchivedDone,
      send: (repository) => repository.updateProject(
        project.id,
        ProjectChanges(isArchived: archived),
      ),
    );
  }

  /// Counts what goes with the project before asking; once deleted, the
  /// project's screen and whatever covers it close.
  Future<void> deleteProject(Project project) async {
    final l10n = context.l10n;
    final subtree = projectSubtreeIds(
      project.id,
      ref.read(projectsProvider).value ?? const [],
    );
    int? taskCount;
    try {
      final tasks =
          await ref
              .read(taskRepositoryProvider)
              ?.watchSearchableTasks()
              .first ??
          const <Task>[];
      taskCount = tasks
          .where((task) => subtree.contains(task.projectId))
          .length;
    } on Object catch (error) {
      _log.warning('Counting tasks failed: ${error.runtimeType}');
    }
    if (!mounted) return;
    final confirmed = await confirmDeleteProject(
      context,
      project: project.displayTitle(l10n),
      taskCount: taskCount,
      subprojectCount: subtree.length - 1,
      defaultProject: _defaultProjectBelow(project.id)?.displayTitle(l10n),
    );
    if (!confirmed || !mounted) return;
    final router = GoRouter.of(context);
    final modals = ref.read(rootModalRoutesProvider);
    final deleted = await _send(
      ProjectChange.delete,
      project,
      done: l10n.projectDeleted,
      send: (repository) => repository.deleteProject(project.id),
    );
    if (!deleted) return;
    modals.closeAll();
    if (await popPagesOverShell(router)) router.go(AppRoutes.projects);
  }

  /// The user's default project when it is below [projectId], so that
  /// deleting or archiving [projectId] takes it along: the server allows
  /// both, and only refuses them for the default project itself.
  Project? _defaultProjectBelow(int projectId) {
    final defaultId = ref.read(userSettingsProvider).value?.defaultProjectId;
    if (defaultId == null || defaultId == projectId) return null;
    final projects = ref.read(projectsProvider).value ?? const <Project>[];
    if (!projectSubtreeIds(projectId, projects).contains(defaultId)) {
      return null;
    }
    return projects.where((p) => p.id == defaultId).firstOrNull;
  }
}

/// An item of the project menu, laid out like its Follow item: a muted
/// icon, or one in [color] with the label.
PopupMenuItem<T> projectMenuItem<T>(
  T value, {
  required IconData icon,
  required String label,
  Color? color,
  bool enabled = true,
  String? hint,
}) => PopupMenuItem(
  value: value,
  enabled: enabled,
  child: Row(
    children: [
      ProjectMenuIcon(icon, color: color),
      const SizedBox(width: 12),
      Flexible(
        child: hint == null
            ? Text(label, style: TextStyle(color: color))
            : _LabelAndHint(label: label, hint: hint),
      ),
    ],
  ),
);

class ProjectMenuIcon extends StatelessWidget {
  const new(this.icon, {this.color, super.key});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => Icon(
    icon,
    color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

class _LabelAndHint extends StatelessWidget {
  const new({required this.label, required this.hint});

  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 2),
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
