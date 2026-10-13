import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/paged_list.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/subscription_repository.dart';
import 'package:vikunja_mobile/core/repositories/subscription_repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/sync/application/outbox_providers.dart';
import 'package:vikunja_mobile/features/sync/presentation/sync_progress_bar.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/follow/follow_controller.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_list_actions.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

enum _Action { toggleShowDone, follow }

class ProjectTasksScreen extends ConsumerStatefulWidget {
  const new({required this.projectId, super.key});

  final int projectId;

  @override
  ConsumerState<ProjectTasksScreen> createState() => _ProjectTasksScreenState();
}

class _ProjectTasksScreenState extends ConsumerState<ProjectTasksScreen>
    with
        RefreshableList<ProjectTasksScreen>,
        TaskListActions<ProjectTasksScreen> {
  bool _showDone = false;
  bool _loadingMore = false;
  Object? _loadMoreFailure;
  late final _follow = FollowController(
    entity: SubscriptionEntity.project,
    read: (id) => _subscriptions().forProject(id),
    write: (id, {required subscribed}) =>
        _subscriptions().setProjectSubscribed(id, subscribed: subscribed),
  );

  /// Saved filters show as projects with ids below zero; nobody follows
  /// them.
  bool get _followable => widget.projectId > 0;

  @override
  void initState() {
    super.initState();
    if (_followable) unawaited(_follow.load(widget.projectId));
  }

  @override
  void dispose() {
    _follow.dispose();
    super.dispose();
  }

  SubscriptionRepository _subscriptions() =>
      ref.read(subscriptionRepositoryProvider) ??
      (throw StateError('No account is signed in'));

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
    clearLeavingTasks();
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

  Future<void> _toggleFollow() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final titles = {
      for (final project in ref.read(projectsProvider).value ?? <Project>[])
        project.id: project.title,
    };
    final before = _follow.value;
    final message = await toggleFollowing(
      context,
      _follow,
      id: widget.projectId,
      projectTitle: (id) => titles[id] ?? l10n.projectUnknownTitle,
    );
    if (!mounted) return;
    final text =
        message ??
        switch ((before, _follow.value)) {
          (FollowKnown(following: false), FollowKnown(following: true)) =>
            l10n.projectFollowed,
          (FollowKnown(following: true), FollowKnown(following: false)) =>
            l10n.projectUnfollowed,
          _ => null,
        };
    if (text == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _toggleShowDone() => setState(() {
    _showDone = !_showDone;
    clearRefreshFailure();
    _loadMoreFailure = null;
    clearLeavingTasks();
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final project = ref.watch(projectByIdProvider(widget.projectId));
    final tasks = ref.watch(
      projectTasksProvider(widget.projectId, showDone: _showDone),
    );
    final now = ref.watch(clockTickProvider);
    final pendingIds =
        ref.watch(pendingTaskIdsProvider).unwrapPrevious().value ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: Text(project?.title ?? l10n.projectUnknownTitle),
        actions: [
          RefreshButton(onPressed: refreshing ? null : refresh),
          PopupMenuButton<_Action>(
            tooltip: l10n.moreActions,
            onSelected: (action) => switch (action) {
              _Action.toggleShowDone => _toggleShowDone(),
              _Action.follow => unawaited(_toggleFollow()),
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: _Action.toggleShowDone,
                checked: _showDone,
                child: Text(l10n.projectTasksShowDone),
              ),
              if (_followable) _followItem(l10n),
            ],
          ),
        ],
        bottom: const SyncProgressBar(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            unawaited(showNewTaskSheet(context, projectId: widget.projectId)),
        tooltip: l10n.newTask,
        child: const Icon(Icons.add),
      ),
      body: buildRefreshable(
        tasks,
        loadingLabel: l10n.projectTasksLoading,
        builder: (page, notice) =>
            _list(page, notice, project, now, pendingIds),
      ),
    );
  }

  /// Labelled by the state the menu opens with: disabled while it is read
  /// or written, as a tap would do nothing; while it is unknown the tap
  /// explains why and loads it again.
  PopupMenuItem<_Action> _followItem(AppLocalizations l10n) {
    final state = _follow.value;
    final following = state is FollowKnown && state.following;
    return PopupMenuItem(
      value: _Action.follow,
      enabled: switch (state) {
        FollowUnknown(:final loading) => !loading,
        FollowKnown(:final saving) => !saving,
      },
      child: Row(
        children: [
          Icon(
            following ? Icons.notifications_off_outlined : Icons.notifications,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(switch (state) {
              FollowUnknown(loading: true) => l10n.followChecking,
              _ when following => l10n.unfollowProject,
              _ => l10n.followProject,
            }),
          ),
        ],
      ),
    );
  }

  Widget _list(
    PagedList<Task> page,
    Widget? notice,
    Project? project,
    DateTime now,
    Set<int> pendingIds,
  ) {
    final l10n = context.l10n;
    final items = withLeavingTasks(page.items);
    if (items.isEmpty) {
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
            itemCount: items.length,
            itemBuilder: (context, index) {
              final task = items[index];
              return TaskRow(
                key: ValueKey(task.id),
                task: task,
                now: now,
                pending: pendingIds.contains(task.id),
                onTap: () => unawaited(
                  showTaskDetail(context, task: task, project: project),
                ),
                onDoneChanged: (done) =>
                    unawaited(setTaskDone(task, done: done)),
                onFavoriteChanged: (favorite) =>
                    unawaited(setTaskFavorite(task, favorite: favorite)),
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
          // Room for the floating action button below the last row.
          const SliverSafeArea(
            top: false,
            sliver: SliverToBoxAdapter(child: SizedBox(height: 88)),
          ),
        ],
      ),
    );
  }
}
