import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';
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
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_row.dart';
import 'package:vikunja_mobile/features/smart_lists/application/smart_list_providers.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/smart_list_row.dart';
import 'package:vikunja_mobile/features/sync/presentation/sync_progress_bar.dart';

enum _Action { toggleArchived }

/// The web's sidebar: the favourites (the Favorites list, saved filters and
/// projects), every saved filter, and the project tree, archived projects
/// on request.
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

  void _open(int projectId) => context.go(AppRoutes.project(projectId));

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
          RefreshButton(onPressed: refreshing ? null : refresh),
          PopupMenuButton<_Action>(
            tooltip: l10n.moreActions,
            onSelected: (action) => switch (action) {
              _Action.toggleArchived => _save(
                preferences.copyWith(showArchived: !preferences.showArchived),
              ),
            },
            itemBuilder: (context) => [
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
          onToggle: (projectId) => _toggle(preferences, projectId),
        ),
      ),
    );
  }
}

class _Sections extends StatelessWidget {
  const new({
    required this.projects,
    required this.preferences,
    required this.savedFilters,
    required this.favoriteTaskCount,
    required this.notice,
    required this.onOpen,
    required this.onToggle,
  });

  final List<Project> projects;
  final ProjectTreePreferences preferences;
  final List<SavedFilterRef> savedFilters;

  /// The Favorites list shows while there is one, as on the server.
  final int favoriteTaskCount;
  final Widget? notice;
  final ValueChanged<int> onOpen;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final favouriteFilters = [
      for (final filter in savedFilters)
        if (filter.isFavorite) filter,
    ];
    final favourites = favouriteProjects(projects);
    final rows = flattenProjectTree(
      buildProjectTree(projects, includeArchived: preferences.showArchived),
      collapsedIds: preferences.collapsed,
    );
    final hasFavourites =
        favoriteTaskCount > 0 ||
        favouriteFilters.isNotEmpty ||
        favourites.isNotEmpty;
    if (rows.isEmpty && !hasFavourites && savedFilters.isEmpty) {
      return CenteredScrollView(
        header: notice,
        child: EmptyState(
          icon: Icons.folder_open,
          title: l10n.projectsEmptyTitle,
          body: l10n.projectsEmptyBody,
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
      onTap: () => onOpen(filter.projectId),
    );

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (notice case final notice?) NoticeSliver(notice: notice),
        if (hasFavourites) ...[
          SliverToBoxAdapter(
            child: ListSectionHeader(title: l10n.projectsFavouritesHeading),
          ),
          SliverList.list(
            children: [
              if (favoriteTaskCount > 0)
                SmartListRow(
                  key: const ValueKey('favorites'),
                  icon: Icons.star_outline,
                  title: l10n.projectsFavouriteTasks,
                  subtitle: l10n.smartListOpenTaskCount(favoriteTaskCount),
                  onTap: () => onOpen(Project.favoritesId),
                ),
              for (final filter in favouriteFilters)
                filterRow(filter, 'favourite'),
              for (final project in favourites)
                ProjectRow(
                  key: ValueKey(('favourite', project.id)),
                  project: project,
                  onTap: () => onOpen(project.id),
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
              for (final filter in savedFilters) filterRow(filter, 'filter'),
            ],
          ),
        ],
        if (rows.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: ListSectionHeader(title: l10n.projectsAllHeading),
          ),
          SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              final project = row.node.project;
              return ProjectRow(
                key: ValueKey(('tree', project.id)),
                project: project,
                depth: row.depth,
                childCount: row.node.children.length,
                expanded: !preferences.collapsed.contains(project.id),
                onToggleExpanded: () => onToggle(project.id),
                onTap: () => onOpen(project.id),
              );
            },
          ),
        ],
        const SliverSafeArea(
          top: false,
          sliver: SliverToBoxAdapter(child: SizedBox(height: 16)),
        ),
      ],
    );
  }
}
