import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/paged_list.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

enum _Action { toggleShowDone }

class ProjectTasksScreen extends ConsumerStatefulWidget {
  const new({required this.projectId, super.key});

  final int projectId;

  @override
  ConsumerState<ProjectTasksScreen> createState() => _ProjectTasksScreenState();
}

class _ProjectTasksScreenState extends ConsumerState<ProjectTasksScreen>
    with RefreshableList<ProjectTasksScreen> {
  bool _showDone = false;
  bool _loadingMore = false;
  Object? _loadMoreFailure;

  @override
  ProviderListenable<Object?> get repositoryProvider => taskRepositoryProvider;

  @override
  Future<void>? startRefresh() {
    final tasks = ref.read(taskRepositoryProvider);
    if (tasks == null) return null;
    // The refresh's own setState shows the change.
    _loadMoreFailure = null;
    return tasks.refreshProjectTasks(widget.projectId, showDone: _showDone);
  }

  @override
  void onRepositoryReplaced() {
    super.onRepositoryReplaced();
    _loadMoreFailure = null;
  }

  Future<void> _loadMore() async {
    final tasks = ref.read(taskRepositoryProvider);
    if (tasks == null || _loadingMore) return;
    setState(() {
      _loadingMore = true;
      _loadMoreFailure = null;
    });
    try {
      await tasks.loadMoreProjectTasks(widget.projectId, showDone: _showDone);
    } on Object catch (error) {
      if (mounted) setState(() => _loadMoreFailure = error);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  bool _onScroll(ScrollNotification notification, bool hasMore) {
    // After a failure the user retries by hand, not by scrolling.
    if (hasMore &&
        !_loadingMore &&
        !refreshing &&
        _loadMoreFailure == null &&
        notification.metrics.extentAfter < 300 &&
        notification is ScrollUpdateNotification) {
      unawaited(_loadMore());
    }
    return false;
  }

  void _toggleShowDone() => setState(() {
    _showDone = !_showDone;
    clearRefreshFailure();
    _loadMoreFailure = null;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final project = ref.watch(projectByIdProvider(widget.projectId));
    final tasks = ref.watch(
      projectTasksProvider(widget.projectId, showDone: _showDone),
    );
    final now = ref.watch(clockTickProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(project?.title ?? l10n.projectUnknownTitle),
        actions: [
          RefreshButton(onPressed: refreshing ? null : refresh),
          PopupMenuButton<_Action>(
            tooltip: l10n.moreActions,
            onSelected: (action) => switch (action) {
              _Action.toggleShowDone => _toggleShowDone(),
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: _Action.toggleShowDone,
                checked: _showDone,
                child: Text(l10n.projectTasksShowDone),
              ),
            ],
          ),
        ],
      ),
      body: buildRefreshable(
        tasks,
        loadingLabel: l10n.projectTasksLoading,
        builder: (page, notice) => _list(page, notice, project, now),
      ),
    );
  }

  Widget _list(
    PagedList<Task> page,
    Widget? notice,
    Project? project,
    DateTime now,
  ) {
    final l10n = context.l10n;
    if (page.items.isEmpty) {
      return CenteredScrollView(
        header: notice,
        child: EmptyState(
          icon: Icons.task_alt,
          title: _showDone
              ? l10n.projectTasksEmptyAllTitle
              : l10n.projectTasksEmptyTitle,
          body: _showDone
              ? l10n.projectTasksEmptyAllBody
              : l10n.projectTasksEmptyBody,
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) => _onScroll(notification, page.hasMore),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (notice case final notice?) NoticeSliver(notice: notice),
          SliverList.builder(
            itemCount: page.items.length,
            itemBuilder: (context, index) {
              final task = page.items[index];
              return TaskRow(
                task: task,
                now: now,
                onTap: () => unawaited(
                  showTaskDetail(context, task: task, project: project),
                ),
              );
            },
          ),
          if (page.hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: switch (_loadMoreFailure) {
                  final failure? => DataFailureCard(
                    error: failure,
                    stale: true,
                    onRetry: _loadMore,
                  ),
                  null when _loadingMore => Center(
                    child: CircularProgressIndicator.adaptive(
                      semanticsLabel: l10n.projectTasksLoadingMore,
                    ),
                  ),
                  null => Center(
                    child: TextButton(
                      onPressed: _loadMore,
                      child: Text(l10n.projectTasksLoadMore),
                    ),
                  ),
                },
              ),
            ),
          const SliverSafeArea(
            top: false,
            sliver: SliverToBoxAdapter(child: SizedBox(height: 16)),
          ),
        ],
      ),
    );
  }
}
