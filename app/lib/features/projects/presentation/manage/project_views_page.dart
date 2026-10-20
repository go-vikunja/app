import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/project_view_repository.dart';
import 'package:vikunja_mobile/core/repositories/project_view_repository_providers.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_change_failure.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_confirmations.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/view_form_sheet.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/view_labels.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_view_labels.dart';

final _log = Logger('ProjectViews');

enum _ViewAction { edit, moveUp, moveDown, delete }

/// A project's views in the web's order, every kind, with their own
/// options: edit, move up and down, delete (never the last one). Each
/// change goes to the server at once, one at a time.
class ProjectViewsPage extends ConsumerStatefulWidget {
  const new({required this.projectId, super.key});

  final int projectId;

  @override
  ConsumerState<ProjectViewsPage> createState() => _ProjectViewsPageState();
}

class _ProjectViewsPageState extends ConsumerState<ProjectViewsPage> {
  /// The view a change is on its way for.
  int? _busyViewId;

  void _announce(String message) => unawaited(
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    ),
  );

  Future<void> _change(
    int viewId, {
    required String changed,
    required Future<void> Function(ProjectViewRepository repository) send,
  }) async {
    final repository = ref.read(projectViewRepositoryProvider);
    if (repository == null || _busyViewId != null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyViewId = viewId);
    try {
      await send(repository);
      if (!mounted) return;
      unawaited(HapticFeedback.selectionClick());
      _announce(changed);
    } on Object catch (error) {
      _log.warning('Changing a view failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              projectChangeFailureText(l10n, error, ProjectChange.view),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busyViewId = null);
    }
  }

  Future<void> _create() {
    final l10n = context.l10n;
    return showViewFormSheet(
      context,
      projectId: widget.projectId,
      onSaved: () {
        if (mounted) _announce(l10n.projectViewCreated);
      },
    );
  }

  Future<void> _edit(ProjectView view) {
    final l10n = context.l10n;
    return showViewFormSheet(
      context,
      projectId: widget.projectId,
      view: view,
      onSaved: () {
        if (mounted) _announce(l10n.projectViewSaved);
      },
    );
  }

  Future<void> _delete(ProjectView view) async {
    final l10n = context.l10n;
    final confirmed = await confirmDeleteView(
      context,
      view: viewTitle(l10n, view),
    );
    if (!confirmed || !mounted) return;
    await _change(
      view.id,
      changed: l10n.projectViewDeleted,
      send: (repository) => repository.deleteView(widget.projectId, view.id),
    );
  }

  void _onAction(ProjectView view, int index, _ViewAction action) {
    final l10n = context.l10n;
    unawaited(switch (action) {
      _ViewAction.edit => _edit(view),
      _ViewAction.moveUp => _change(
        view.id,
        changed: l10n.movedUp,
        send: (repository) =>
            repository.moveView(widget.projectId, view.id, toIndex: index - 1),
      ),
      _ViewAction.moveDown => _change(
        view.id,
        changed: l10n.movedDown,
        send: (repository) =>
            repository.moveView(widget.projectId, view.id, toIndex: index + 1),
      ),
      _ViewAction.delete => _delete(view),
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Not projectByIdProvider: a change of the views alone must show.
    final projects = ref.watch(projectsProvider);
    final project = (projects.value ?? const <Project>[])
        .where((project) => project.id == widget.projectId)
        .firstOrNull;
    final views = sortedViews(project?.views ?? const []);
    final busy = _busyViewId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.projectViews),
        actions: [
          if (project != null)
            IconButton(
              onPressed: busy ? null : () => unawaited(_create()),
              tooltip: l10n.projectViewNew,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: switch ((project, projects.hasValue)) {
        (final project?, _) => ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                l10n.projectViewsIntro(project.displayTitle(l10n)),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final (index, view) in views.indexed)
              _ViewRow(
                key: ValueKey(view.id),
                view: view,
                busy: _busyViewId == view.id,
                enabled: !busy,
                canMoveUp: planViewMove(views, view.id, index - 1) != null,
                canMoveDown:
                    index < views.length - 1 &&
                    planViewMove(views, view.id, index + 1) != null,
                canDelete: views.length > 1,
                onTap: () => unawaited(_edit(view)),
                onAction: (action) => _onAction(view, index, action),
              ),
          ],
        ),
        (_, true) => CenteredScrollView(
          child: EmptyState(
            icon: Icons.search_off,
            title: l10n.projectGoneTitle,
            body: l10n.projectGoneBody,
          ),
        ),
        _ => CenteredScrollView(
          child: LoadingPlaceholder(label: l10n.projectsLoading),
        ),
      },
    );
  }
}

class _ViewRow extends StatelessWidget {
  const new({
    required this.view,
    required this.busy,
    required this.enabled,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.canDelete,
    required this.onTap,
    required this.onAction,
    super.key,
  });

  final ProjectView view;

  /// A change of this view is on its way.
  final bool busy;

  /// False while a change of any view is on its way.
  final bool enabled;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool canDelete;
  final VoidCallback onTap;
  final ValueChanged<_ViewAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final title = viewTitle(l10n, view);
    return ListTile(
      enabled: enabled,
      leading: Icon(viewKindIcon(view.kind), color: colors.onSurfaceVariant),
      title: Text(title),
      subtitle: Text(viewKindOptionLabel(l10n, view.kind)),
      onTap: onTap,
      trailing: busy
          ? SizedBox.square(
              dimension: kMinInteractiveDimension,
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    semanticsLabel: l10n.projectSaving,
                  ),
                ),
              ),
            )
          : PopupMenuButton<_ViewAction>(
              tooltip: l10n.projectViewOptionsFor(title),
              enabled: enabled,
              icon: const Icon(Icons.more_vert),
              onSelected: onAction,
              itemBuilder: (context) => [
                _item(_ViewAction.edit, Icons.edit_outlined, l10n.projectEdit),
                if (canMoveUp)
                  _item(_ViewAction.moveUp, Icons.arrow_upward, l10n.moveUp),
                if (canMoveDown)
                  _item(
                    _ViewAction.moveDown,
                    Icons.arrow_downward,
                    l10n.moveDown,
                  ),
                _item(
                  _ViewAction.delete,
                  Icons.delete_outline,
                  l10n.projectViewDelete,
                  color: canDelete ? colors.error : null,
                  enabled: canDelete,
                  hint: canDelete ? null : l10n.projectViewLastOne,
                ),
              ],
            ),
    );
  }

  static PopupMenuItem<_ViewAction> _item(
    _ViewAction value,
    IconData icon,
    String label, {
    Color? color,
    bool enabled = true,
    String? hint,
  }) => PopupMenuItem(
    value: value,
    enabled: enabled,
    child: IgnorePointer(
      child: ListTile(
        enabled: enabled,
        leading: Icon(icon, color: color),
        title: Text(label, style: TextStyle(color: color)),
        subtitle: hint == null ? null : Text(hint),
      ),
    ),
  );
}
