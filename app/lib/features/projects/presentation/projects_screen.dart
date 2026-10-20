import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_switcher_button.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/projects/application/project_moves.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/new_project_sheet.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_move_failure.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_row.dart';
import 'package:vikunja_mobile/features/projects/presentation/reorder_slot.dart';
import 'package:vikunja_mobile/features/search/presentation/search_button.dart';
import 'package:vikunja_mobile/features/smart_lists/application/smart_list_providers.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/smart_list_row.dart';
import 'package:vikunja_mobile/features/sync/presentation/sync_progress_bar.dart';

final _log = Logger('Projects');

enum _Action { refresh, newSavedFilter, toggleArchived }

/// The web's sidebar: the favourites (the Favorites list, saved filters and
/// projects), every saved filter, and the project tree, archived projects
/// on request. In the tree a long press lifts a project with its
/// subprojects, to drop it between other projects or onto one, and screen
/// readers move it with the row's actions; each move goes to the server
/// at once. New projects start from the app bar or the empty state, new
/// saved filters from the menu, the end of their section or the empty
/// state.
class ProjectsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen>
    with RefreshableList<ProjectsScreen> {
  @override
  ProviderListenable<Object?> get repositoryProvider =>
      projectRepositoryProvider;

  @override
  Future<void>? startRefresh() =>
      ref.read(projectRepositoryProvider)?.refresh();

  void _save(ProjectTreePreferences preferences) => unawaited(
    ref.read(listPreferencesProvider)?.saveProjectTree(preferences),
  );

  void _toggle(ProjectTreePreferences preferences, int projectId) {
    final collapsed = {...preferences.collapsed};
    if (!collapsed.remove(projectId)) collapsed.add(projectId);
    _save(preferences.copyWith(collapsed: collapsed));
  }

  void _expand(int projectId) {
    final preferences =
        ref.read(projectTreePreferencesProvider).value ??
        const ProjectTreePreferences();
    if (!preferences.collapsed.contains(projectId)) return;
    _save(
      preferences.copyWith(
        collapsed: {...preferences.collapsed}..remove(projectId),
      ),
    );
  }

  void _open(int projectId) => context.go(AppRoutes.project(projectId));

  void _createProject() => unawaited(createProjectAndOpen(context));

  void _createSavedFilter() =>
      unawaited(GoRouter.of(context).push(AppRoutes.savedFilterNew));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final projects = ref.watch(projectsProvider);
    final treePreferences = ref.watch(projectTreePreferencesProvider);
    final preferences = treePreferences.value ?? const ProjectTreePreferences();
    final savedFiltersValue = ref.watch(savedFiltersProvider);
    final savedFilters = savedFiltersValue.value ?? const [];
    final (favoritesLoaded, favoriteTaskCount) = ref.watch(
      favoriteTasksProvider.select(
        (tasks) => (tasks.hasValue || tasks.hasError, tasks.value?.length ?? 0),
      ),
    );
    // The tree would otherwise show expanded for a moment, then collapse,
    // and be pushed down by the sections above it as they arrive.
    final ready =
        (treePreferences.hasValue || treePreferences.hasError) &&
        (savedFiltersValue.hasValue || savedFiltersValue.hasError) &&
        favoritesLoaded;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabProjects),
        actions: [
          const SearchButton(),
          IconButton(
            onPressed: _createProject,
            tooltip: l10n.projectNew,
            icon: const Icon(Icons.add),
          ),
          // Refresh is in the menu, where it leaves the title room on a
          // narrow phone; pulling the list refreshes too.
          PopupMenuButton<_Action>(
            tooltip: l10n.moreActions,
            onSelected: (action) => switch (action) {
              _Action.refresh => unawaited(refresh()),
              _Action.newSavedFilter => _createSavedFilter(),
              _Action.toggleArchived => _save(
                preferences.copyWith(showArchived: !preferences.showArchived),
              ),
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _Action.refresh,
                enabled: !refreshing,
                child: Text(l10n.refresh),
              ),
              PopupMenuItem(
                value: _Action.newSavedFilter,
                child: Text(l10n.savedFilterNew),
              ),
              CheckedPopupMenuItem(
                value: _Action.toggleArchived,
                checked: preferences.showArchived,
                child: Text(l10n.projectsShowArchived),
              ),
            ],
          ),
          const AccountSwitcherButton(),
        ],
        bottom: const SyncProgressBar(),
      ),
      body: buildRefreshable(
        ready ? projects : const AsyncLoading<List<Project>>(),
        loadingLabel: l10n.projectsLoading,
        builder: (projects, notice) => _Sections(
          projects: projects,
          preferences: preferences,
          savedFilters: savedFilters,
          favoriteTaskCount: favoriteTaskCount,
          notice: notice,
          onOpen: _open,
          onCreate: _createProject,
          onCreateSavedFilter: _createSavedFilter,
          onToggle: (projectId) => _toggle(preferences, projectId),
          onExpand: _expand,
        ),
      ),
    );
  }
}

@immutable
final class _ProjectDrag {
  const new(this.projectId);

  final int projectId;
}

@immutable
sealed class _TreeDrop {
  const new();
}

/// Into the gap above the row at [rowIndex] (below the last row when it is
/// the row count), on the level of [depth], under [parentId] at [index] of
/// its children counted without the project.
final class _Gap extends _TreeDrop {
  const new({
    required this.rowIndex,
    required this.depth,
    required this.parentId,
    required this.index,
  });

  final int rowIndex;
  final int depth;
  final int parentId;
  final int index;

  @override
  bool operator ==(Object other) =>
      other is _Gap &&
      other.rowIndex == rowIndex &&
      other.depth == depth &&
      other.parentId == parentId &&
      other.index == index;

  @override
  int get hashCode => Object.hash(rowIndex, depth, parentId, index);
}

/// Onto the row at [rowIndex]: the last subproject of [projectId].
final class _Into extends _TreeDrop {
  const new({required this.rowIndex, required this.projectId});

  final int rowIndex;
  final int projectId;

  @override
  bool operator ==(Object other) =>
      other is _Into &&
      other.rowIndex == rowIndex &&
      other.projectId == projectId;

  @override
  int get hashCode => Object.hash(rowIndex, projectId);
}

class _Sections extends ConsumerStatefulWidget {
  const new({
    required this.projects,
    required this.preferences,
    required this.savedFilters,
    required this.favoriteTaskCount,
    required this.notice,
    required this.onOpen,
    required this.onCreate,
    required this.onCreateSavedFilter,
    required this.onToggle,
    required this.onExpand,
  });

  final List<Project> projects;
  final ProjectTreePreferences preferences;
  final List<SavedFilterRef> savedFilters;

  /// The Favorites list shows while there is one, as on the server.
  final int favoriteTaskCount;
  final Widget? notice;
  final ValueChanged<int> onOpen;
  final VoidCallback onCreate;
  final VoidCallback onCreateSavedFilter;
  final ValueChanged<int> onToggle;
  final ValueChanged<int> onExpand;

  @override
  ConsumerState<_Sections> createState() => _SectionsState();
}

class _SectionsState extends ConsumerState<_Sections> {
  /// The part of a row's height at its top and at its bottom that drops
  /// beside it; the middle drops into it.
  static const _edgeShare = 0.25;

  final GlobalKey _treeKey = GlobalKey();
  final _slots = <int, BuildContext>{};
  late final _edgeScroller = DragEdgeScroller(onScrolled: _followPointer);

  List<ProjectTreeRow> _rows = const [];
  ProjectTreeMoves _moves = ProjectTreeMoves(const [], all: const []);
  int? _held;
  Offset? _pointer;
  ({_TreeDrop drop, ProjectMovePlan plan})? _target;
  MoveProject? _sending;
  var _landed = false;

  @override
  void didUpdateWidget(_Sections oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A move the server took shows until the local write arrives.
    if (_landed && !identical(oldWidget.projects, widget.projects)) {
      _landed = false;
      _sending = null;
    }
  }

  @override
  void dispose() {
    _edgeScroller.stop();
    super.dispose();
  }

  void _announce(String message) => unawaited(
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    ),
  );

  /// Sends one move at a time, showing it at once, faded until the server
  /// took it, then announcing [moved]; the subprojects of [expand] show. A
  /// failure puts the project back and says why.
  Future<void> _send(
    MoveProject move, {
    required String moved,
    int? expand,
  }) async {
    final repository = ref.read(projectRepositoryProvider);
    if (repository == null) return;
    final l10n = context.l10n;
    if (_sending != null) {
      unawaited(HapticFeedback.heavyImpact());
      _announce(l10n.projectMoveWait);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final parentChanged =
        move.parentProjectId !=
        _moves.projectOf(move.projectId)?.parentProjectId;
    final projectsBefore = widget.projects;
    if (expand != null) widget.onExpand(expand);
    setState(() => _sending = move);
    try {
      await repository.moveProject(
        move.projectId,
        position: move.position,
        parentProjectId: move.parentProjectId,
      );
      if (!mounted) return;
      unawaited(HapticFeedback.selectionClick());
      _announce(moved);
      if (identical(widget.projects, projectsBefore)) {
        _landed = true;
      } else {
        setState(() => _sending = null);
      }
    } on Object catch (error) {
      _log.warning('Moving a project failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              projectMoveFailureText(l10n, error, parentChanged: parentChanged),
            ),
          ),
        );
      if (mounted) setState(() => _sending = null);
    }
  }

  MoveProject? _planned(
    int projectId, {
    required int parentId,
    required int index,
  }) => switch (_moves.plan(projectId, parentId: parentId, index: index)) {
    final MoveProject move => move,
    _ => null,
  };

  Map<CustomSemanticsAction, VoidCallback> _actionsFor(Project project) {
    final l10n = context.l10n;
    final moves = _moves;
    final parentId = moves.shownParentOf(project.id);
    final siblings = moves.childrenOf(parentId);
    final index = siblings.indexWhere((other) => other.id == project.id);
    final up = index > 0
        ? _planned(project.id, parentId: parentId, index: index - 1)
        : null;
    final down = index >= 0 && index < siblings.length - 1
        ? _planned(project.id, parentId: parentId, index: index + 1)
        : null;
    final parent = parentId == 0 ? null : moves.projectOf(parentId);
    final grandparentId = moves.shownParentOf(parentId);
    final out = parent == null
        ? null
        : _planned(
            project.id,
            parentId: grandparentId,
            index:
                moves
                    .childrenOf(grandparentId)
                    .indexWhere((other) => other.id == parentId) +
                1,
          );
    final previous = index > 0 ? siblings[index - 1] : null;
    final into = previous == null
        ? null
        : _planned(
            project.id,
            parentId: previous.id,
            index: moves.childrenOf(previous.id).length,
          );
    final parentTitle = parent?.displayTitle(l10n) ?? '';
    final previousTitle = previous?.displayTitle(l10n) ?? '';
    return {
      if (up != null)
        CustomSemanticsAction(label: l10n.moveUp): () =>
            unawaited(_send(up, moved: l10n.movedUp)),
      if (down != null)
        CustomSemanticsAction(label: l10n.moveDown): () =>
            unawaited(_send(down, moved: l10n.movedDown)),
      if (out != null)
        CustomSemanticsAction(label: l10n.projectMoveOut(parentTitle)): () =>
            unawaited(_send(out, moved: l10n.projectMovedOut(parentTitle))),
      if (into != null && previous != null)
        CustomSemanticsAction(label: l10n.projectMoveInto(previousTitle)): () =>
            unawaited(
              _send(
                into,
                moved: l10n.projectMovedInto(previousTitle),
                expand: previous.id,
              ),
            ),
    };
  }

  String _movedBy(MoveProject move) {
    final l10n = context.l10n;
    final project = _moves.projectOf(move.projectId);
    if (project != null && move.parentProjectId == project.parentProjectId) {
      return move.position < project.position ? l10n.movedUp : l10n.movedDown;
    }
    return switch (_moves.projectOf(move.parentProjectId)) {
      final parent? => l10n.projectMovedInto(parent.displayTitle(l10n)),
      null => l10n.projectMovedToTopLevel,
    };
  }

  void _startDrag(int projectId) => setState(() => _held = projectId);

  void _endDrag() {
    _edgeScroller.stop();
    _pointer = null;
    if (!mounted || (_held == null && _target == null)) return;
    setState(() {
      _held = null;
      _target = null;
    });
  }

  void _dragMoved(Offset pointer) {
    _pointer = pointer;
    _followPointer();
  }

  void _followPointer() {
    final pointer = _pointer;
    final held = _held;
    if (!mounted || pointer == null || held == null) return;
    final inside = _treeKey.currentContext;
    final list = inside
        ?.findAncestorStateOfType<ScrollableState>()
        ?.context
        .findRenderObject();
    if (list is! RenderBox ||
        !list.hasSize ||
        !(list.localToGlobal(Offset.zero) & list.size).contains(pointer)) {
      _edgeScroller.stop();
      _setTarget(null);
      return;
    }
    _edgeScroller.follow(inside, pointer);
    final drop = switch (_dropAt(pointer, held)) {
      // Let go on or right around its own row, the project stays without a
      // refusal.
      _Into(:final projectId) ||
      _Gap(parentId: final projectId) when projectId == held => null,
      final drop => drop,
    };
    _setTarget(
      drop == null
          ? null
          : (
              drop: drop,
              plan: switch (drop) {
                _Gap(:final parentId, :final index) => _moves.plan(
                  held,
                  parentId: parentId,
                  index: index,
                ),
                _Into(:final projectId) => _moves.plan(
                  held,
                  parentId: projectId,
                  index: _moves
                      .childrenOf(projectId)
                      .where((project) => project.id != held)
                      .length,
                ),
              },
            ),
    );
  }

  void _setTarget(({_TreeDrop drop, ProjectMovePlan plan})? target) {
    if (target == _target) return;
    setState(() => _target = target);
  }

  /// The drop under [pointer]: beside a row near its top or bottom edge,
  /// into it in the middle, and on the top level below the last row.
  /// Between two rows the level is the lower row's, or the upper row's
  /// after the last row of an open branch.
  _TreeDrop? _dropAt(Offset pointer, int held) {
    final rows = _rows;
    int? lastLaidOut;
    for (var index = 0; index < rows.length; index++) {
      final box = _slots[rows[index].node.project.id]?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (pointer.dy < top) return null;
      final height = box.size.height;
      if (pointer.dy < top + height) {
        final at = (pointer.dy - top) / height;
        if (at < _edgeShare) return _gapAbove(index, held);
        if (at > 1 - _edgeShare) return _gapBelow(index, held);
        return _Into(rowIndex: index, projectId: rows[index].node.project.id);
      }
      lastLaidOut = index;
    }
    if (lastLaidOut != rows.length - 1) return null;
    return _Gap(
      rowIndex: rows.length,
      depth: 0,
      parentId: 0,
      index: _moves.childrenOf(0).where((project) => project.id != held).length,
    );
  }

  /// How many of [projectId]'s siblings, without the held project, come
  /// before it.
  int _siblingsBefore(int projectId, int held) {
    var count = 0;
    for (final sibling in _moves.childrenOf(_moves.shownParentOf(projectId))) {
      if (sibling.id == projectId) break;
      if (sibling.id != held) count++;
    }
    return count;
  }

  _Gap _gapAbove(int rowIndex, int held) {
    final row = _rows[rowIndex];
    final projectId = row.node.project.id;
    return _Gap(
      rowIndex: rowIndex,
      depth: row.depth,
      parentId: _moves.shownParentOf(projectId),
      index: _siblingsBefore(projectId, held),
    );
  }

  _Gap _gapBelow(int rowIndex, int held) {
    final row = _rows[rowIndex];
    final next = rowIndex + 1 < _rows.length ? _rows[rowIndex + 1] : null;
    if (next != null && next.depth >= row.depth) {
      return _gapAbove(rowIndex + 1, held);
    }
    final projectId = row.node.project.id;
    return _Gap(
      rowIndex: rowIndex + 1,
      depth: row.depth,
      parentId: _moves.shownParentOf(projectId),
      index: _siblingsBefore(projectId, held) + (projectId == held ? 0 : 1),
    );
  }

  void _drop() {
    final target = _target;
    _endDrag();
    switch (target) {
      case (:final drop, plan: final MoveProject move):
        unawaited(
          _send(
            move,
            moved: _movedBy(move),
            expand: drop is _Into ? drop.projectId : null,
          ),
        );
      case (drop: _, plan: ProjectMoveRefused()):
        unawaited(HapticFeedback.heavyImpact());
      case _:
        break;
    }
  }

  Set<int> _subtreeRows(int? projectId) {
    if (projectId == null) return const {};
    final start = _rows.indexWhere((row) => row.node.project.id == projectId);
    if (start < 0) return const {};
    final depth = _rows[start].depth;
    return {
      start,
      for (
        var index = start + 1;
        index < _rows.length && _rows[index].depth > depth;
        index++
      )
        index,
    };
  }

  Widget _treeRow(
    BuildContext context,
    int index, {
    required double width,
    required Set<int> heldRows,
  }) {
    final row = _rows[index];
    final project = row.node.project;
    final preferences = widget.preferences;
    final archived = _moves.isArchived(project.id);
    final liftable = !archived && _sending == null;
    final target = _target;
    final drop = target != null && target.plan is MoveProject
        ? target.drop
        : null;
    final projectRow = ProjectRow(
      project: project,
      depth: row.depth,
      childCount: row.node.children.length,
      expanded: !preferences.collapsed.contains(project.id),
      onToggleExpanded: () => widget.onToggle(project.id),
      onTap: () => widget.onOpen(project.id),
      actions: archived ? const {} : _actionsFor(project),
    );
    return ReorderSlot<int>(
      key: ValueKey(('tree', project.id)),
      id: project.id,
      slots: _slots,
      held: heldRows.contains(index),
      lineAbove: switch (drop) {
        _Gap(:final rowIndex, :final depth) when rowIndex == index =>
          ProjectRow.indentOf(depth),
        _ => null,
      },
      lineBelow: switch (drop) {
        _Gap(:final rowIndex, :final depth)
            when rowIndex == _rows.length && index == _rows.length - 1 =>
          ProjectRow.indentOf(depth),
        _ => null,
      },
      dropsInto: drop is _Into && drop.rowIndex == index,
      // The server refuses to move an archived project, and a move waits
      // for the one before.
      child: GestureDetector(
        onLongPress: liftable
            ? null
            : () => unawaited(HapticFeedback.heavyImpact()),
        excludeFromSemantics: true,
        child: LongPressDraggable<_ProjectDrag>(
          data: _ProjectDrag(project.id),
          maxSimultaneousDrags: liftable ? 1 : 0,
          dragAnchorStrategy: liftedAboveFinger,
          feedback: LiftedRows(
            width: width,
            child: ProjectRow(
              project: project,
              childCount: row.node.children.length,
              onTap: () {},
            ),
          ),
          onDragStarted: () => _startDrag(project.id),
          onDragUpdate: (details) => _dragMoved(details.globalPosition),
          onDragEnd: (_) => _endDrag(),
          child: LiftableRow(child: projectRow),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sending = _sending;
    final projects = sending == null
        ? widget.projects
        : [for (final project in widget.projects) sending.applyTo(project)];
    final preferences = widget.preferences;
    final savedFilters = widget.savedFilters;
    final favouriteFilters = [
      for (final filter in savedFilters)
        if (filter.isFavorite) filter,
    ];
    final favourites = favouriteProjects(projects);
    final tree = buildProjectTree(
      projects,
      includeArchived: preferences.showArchived,
    );
    _moves = ProjectTreeMoves(tree, all: projects);
    final rows = _rows = flattenProjectTree(
      tree,
      collapsedIds: preferences.collapsed,
    );
    final hasFavourites =
        widget.favoriteTaskCount > 0 ||
        favouriteFilters.isNotEmpty ||
        favourites.isNotEmpty;
    if (rows.isEmpty && !hasFavourites && savedFilters.isEmpty) {
      return CenteredScrollView(
        header: widget.notice,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyState(
              icon: Icons.folder_open,
              title: l10n.projectsEmptyTitle,
              body: l10n.projectsEmptyBody,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: FilledButton.icon(
                onPressed: widget.onCreate,
                icon: const Icon(Icons.add),
                label: Text(l10n.projectNew),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
              child: OutlinedButton.icon(
                onPressed: widget.onCreateSavedFilter,
                icon: const Icon(Icons.filter_list),
                label: Text(l10n.savedFilterNew),
              ),
            ),
          ],
        ),
      );
    }

    Widget filterRow(SavedFilterRef filter, String section) => SmartListRow(
      key: ValueKey((section, filter.projectId)),
      icon: Icons.filter_list,
      title: projectDisplayTitle(
        l10n,
        filter.title,
        projectId: filter.projectId,
      ),
      favorite: filter.isFavorite,
      onTap: () => widget.onOpen(filter.projectId),
    );

    final heldRows = {
      ..._subtreeRows(_held),
      ..._subtreeRows(sending?.projectId),
    };
    return LayoutBuilder(
      builder: (context, constraints) => DragTarget<_ProjectDrag>(
        onAcceptWithDetails: (_) => _drop(),
        onLeave: (_) => _setTarget(null),
        builder: (context, _, _) => CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (widget.notice case final notice?) NoticeSliver(notice: notice),
            if (hasFavourites) ...[
              SliverToBoxAdapter(
                child: ListSectionHeader(title: l10n.projectsFavouritesHeading),
              ),
              SliverList.list(
                children: [
                  if (widget.favoriteTaskCount > 0)
                    SmartListRow(
                      key: const ValueKey('favorites'),
                      icon: Icons.star_outline,
                      title: l10n.projectsFavouriteTasks,
                      subtitle: l10n.smartListOpenTaskCount(
                        widget.favoriteTaskCount,
                      ),
                      onTap: () => widget.onOpen(Project.favoritesId),
                    ),
                  for (final filter in favouriteFilters)
                    filterRow(filter, 'favourite'),
                  for (final project in favourites)
                    ProjectRow(
                      key: ValueKey(('favourite', project.id)),
                      project: project,
                      onTap: () => widget.onOpen(project.id),
                    ),
                ],
              ),
            ],
            if (savedFilters.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: ListSectionHeader(title: l10n.savedFiltersHeading),
              ),
              SliverList.list(
                children: [
                  for (final filter in savedFilters)
                    filterRow(filter, 'filter'),
                  _NewSavedFilterRow(onTap: widget.onCreateSavedFilter),
                ],
              ),
            ],
            if (rows.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: ListSectionHeader(title: l10n.projectsAllHeading),
              ),
              SliverList.builder(
                key: _treeKey,
                itemCount: rows.length,
                findChildIndexCallback: (key) {
                  if (key case ValueKey<(String, int)>(value: (_, final id))) {
                    final index = rows.indexWhere(
                      (row) => row.node.project.id == id,
                    );
                    return index < 0 ? null : index;
                  }
                  return null;
                },
                itemBuilder: (context, index) => _treeRow(
                  context,
                  index,
                  width: constraints.maxWidth,
                  heldRows: heldRows,
                ),
              ),
            ],
            SliverSafeArea(
              top: false,
              // While a project is held, room below the last row to drop
              // it on the top level.
              sliver: SliverToBoxAdapter(
                child: SizedBox(height: _held == null ? 16 : 72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewSavedFilterRow extends StatelessWidget {
  const new({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      key: const ValueKey('new saved filter'),
      onTap: onTap,
      contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 8),
      leading: ExcludeSemantics(child: Icon(Icons.add, color: colors.primary)),
      title: Text(
        context.l10n.savedFilterNew,
        style: TextStyle(color: colors.primary),
      ),
    );
  }
}
