import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_row.dart';
import 'package:vikunja_mobile/features/sync/presentation/sync_progress_bar.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen>
    with RefreshableList<ProjectsScreen> {
  final _collapsed = <int>{};

  @override
  ProviderListenable<Object?> get repositoryProvider =>
      projectRepositoryProvider;

  @override
  Future<void>? startRefresh() =>
      ref.read(projectRepositoryProvider)?.refresh();

  @override
  void onRepositoryReplaced() {
    super.onRepositoryReplaced();
    _collapsed.clear();
  }

  void _toggle(int projectId) => setState(() {
    if (!_collapsed.remove(projectId)) _collapsed.add(projectId);
  });

  void _open(Project project) => context.go(AppRoutes.project(project.id));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final projects = ref.watch(projectsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabProjects),
        actions: [RefreshButton(onPressed: refreshing ? null : refresh)],
        bottom: const SyncProgressBar(),
      ),
      body: buildRefreshable(
        projects,
        loadingLabel: l10n.projectsLoading,
        builder: _tree,
      ),
    );
  }

  Widget _tree(List<Project> projects, Widget? notice) {
    final l10n = context.l10n;
    final favourites = favouriteProjects(projects);
    final rows = flattenProjectTree(
      buildProjectTree(projects),
      collapsedIds: _collapsed,
    );
    if (rows.isEmpty) {
      return CenteredScrollView(
        header: notice,
        child: EmptyState(
          icon: Icons.folder_open,
          title: l10n.projectsEmptyTitle,
          body: l10n.projectsEmptyBody,
        ),
      );
    }
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (notice case final notice?) NoticeSliver(notice: notice),
        if (favourites.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: ListSectionHeader(title: l10n.projectsFavouritesHeading),
          ),
          SliverList.builder(
            itemCount: favourites.length,
            itemBuilder: (context, index) {
              final project = favourites[index];
              return ProjectRow(
                key: ValueKey(('favourite', project.id)),
                project: project,
                onTap: () => _open(project),
              );
            },
          ),
        ],
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
              expanded: !_collapsed.contains(project.id),
              onToggleExpanded: () => _toggle(project.id),
              onTap: () => _open(project),
            );
          },
        ),
        const SliverSafeArea(
          top: false,
          sliver: SliverToBoxAdapter(child: SizedBox(height: 16)),
        ),
      ],
    );
  }
}
