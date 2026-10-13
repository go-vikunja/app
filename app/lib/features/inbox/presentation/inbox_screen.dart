import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/router/pop_pages_over_shell.dart';
import 'package:vikunja_mobile/core/activity/activity_item.dart';
import 'package:vikunja_mobile/core/repositories/activity_repository.dart';
import 'package:vikunja_mobile/core/repositories/activity_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/inbox/application/activity_sections.dart';
import 'package:vikunja_mobile/features/inbox/application/inbox_providers.dart';
import 'package:vikunja_mobile/features/inbox/application/local_task_lookup.dart';
import 'package:vikunja_mobile/features/inbox/presentation/inbox_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

final _log = Logger('Inbox');

enum _Action { markAllRead }

/// The server's notifications for the active account as this device holds
/// them, newest first by day; a tap marks one read and opens its task or
/// project when it is on this device.
class InboxScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen>
    with RefreshableList<InboxScreen> {
  @override
  ProviderListenable<Object?> get repositoryProvider =>
      activityRepositoryProvider;

  /// Far enough back that what was read elsewhere is read here too.
  @override
  Future<void>? startRefresh() =>
      ref.read(activityRepositoryProvider)?.refresh(wholeWindow: true);

  Future<void> _markAllRead() async {
    try {
      await ref.read(activityRepositoryProvider)?.markAllRead();
    } on Object catch (error) {
      _log.warning('Could not mark all as read: ${error.runtimeType}');
    }
  }

  Future<void> _open(ActivityItem item) async {
    final repository = ref.read(activityRepositoryProvider);
    if (repository == null) return;
    if (!item.isRead) unawaited(_markRead(repository, item.id));
    switch (item.kind) {
      case ActivityKind.projectCreated:
        await _openProject(item.projectId);
      case ActivityKind.taskDeleted:
        _showSnackBar(context.l10n.inboxTaskWasDeleted);
      // No team screen yet; the row itself is all there is.
      case ActivityKind.teamMemberAdded || ActivityKind.other:
        break;
      case _:
        await _openTask(item.taskId);
    }
  }

  Future<void> _markRead(ActivityRepository repository, int id) async {
    try {
      await repository.markRead(id);
    } on Object catch (error) {
      _log.warning('Could not mark a notification read: ${error.runtimeType}');
    }
  }

  Future<void> _openTask(int? taskId) async {
    final tasks = ref.read(taskRepositoryProvider);
    if (tasks == null) return;
    final task = taskId == null ? null : await findLocalTask(tasks, taskId);
    if (!mounted) return;
    if (task == null) {
      _showSnackBar(context.l10n.inboxTaskNotLocal);
      return;
    }
    final project = ref.read(projectRepositoryProvider)?.find(task.projectId);
    await showTaskDetail(context, task: task, project: project);
  }

  /// The project's screen is in a tab: the pages over the shell go first,
  /// this one included, each as if the user went back.
  Future<void> _openProject(int? projectId) async {
    final project = projectId == null
        ? null
        : ref.read(projectRepositoryProvider)?.find(projectId);
    if (project == null) {
      _showSnackBar(context.l10n.inboxProjectNotLocal);
      return;
    }
    final router = GoRouter.of(context);
    if (!await popPagesOverShell(router)) return;
    router.go(AppRoutes.project(project.id));
  }

  void _showSnackBar(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = ref.watch(inboxItemsProvider);
    // Not the badge's count, which leaves the server's reminders out.
    final anyUnread = items.value?.any((item) => !item.isRead) ?? false;
    final now = ref.watch(clockTickProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.inboxTitle),
        actions: [
          RefreshButton(onPressed: refreshing ? null : refresh),
          PopupMenuButton<_Action>(
            tooltip: l10n.moreActions,
            onSelected: (action) => switch (action) {
              _Action.markAllRead => unawaited(_markAllRead()),
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _Action.markAllRead,
                enabled: anyUnread,
                child: Text(l10n.inboxMarkAllRead),
              ),
            ],
          ),
        ],
      ),
      body: buildRefreshable(
        items,
        loadingLabel: l10n.inboxLoading,
        builder: (value, notice) => _InboxList(
          sections: groupActivityByDay(value, now),
          now: now,
          notice: notice,
          onTap: (item) => unawaited(_open(item)),
        ),
      ),
    );
  }
}

class _InboxList extends StatelessWidget {
  const new({
    required this.sections,
    required this.now,
    required this.notice,
    required this.onTap,
  });

  final List<ActivitySection> sections;
  final DateTime now;
  final Widget? notice;
  final ValueChanged<ActivityItem> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (sections.isEmpty) {
      return CenteredScrollView(
        header: notice,
        child: EmptyState(
          icon: Icons.notifications_none,
          title: l10n.inboxEmptyTitle,
          body: l10n.inboxEmptyBody,
        ),
      );
    }
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (notice case final notice?) NoticeSliver(notice: notice),
        for (final section in sections) ...[
          SliverToBoxAdapter(
            child: ListSectionHeader(title: _dayTitle(l10n, section.day)),
          ),
          SliverList.builder(
            itemCount: section.items.length,
            itemBuilder: (context, index) {
              final item = section.items[index];
              return InboxRow(
                key: ValueKey(item.id),
                item: item,
                now: now,
                onTap: () => onTap(item),
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

  String _dayTitle(AppLocalizations l10n, ActivityDay day) => switch (day) {
    ActivityDay.today => l10n.inboxToday,
    ActivityDay.yesterday => l10n.inboxYesterday,
    ActivityDay.earlier => l10n.inboxEarlier,
  };
}
