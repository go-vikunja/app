import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_switcher_button.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/option_sheet.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/inbox/application/inbox_providers.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/search/presentation/search_button.dart';
import 'package:vikunja_mobile/features/sync/application/outbox_providers.dart';
import 'package:vikunja_mobile/features/sync/presentation/sync_progress_bar.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/application/minimum_priority_provider.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_list_actions.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';
import 'package:vikunja_mobile/features/upcoming/application/upcoming_providers.dart';
import 'package:vikunja_mobile/features/upcoming/application/upcoming_sections.dart';
import 'package:vikunja_mobile/features/upcoming/presentation/date_range_labels.dart';
import 'package:vikunja_mobile/features/upcoming/presentation/day_range_picker.dart';
import 'package:vikunja_mobile/features/upcoming/presentation/day_strip.dart';
import 'package:vikunja_mobile/features/upcoming/presentation/timeline_day.dart';

enum _Action { refresh, inbox, toggleOverdue, toggleWithoutDueDate }

enum _CustomRange { pick }

/// The open tasks due in a date range, by day, below the overdue ones; the
/// web's Upcoming with the web's date-range presets. A strip of the range's
/// days picks one of them.
class UpcomingScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<UpcomingScreen> createState() => _UpcomingScreenState();
}

class _UpcomingScreenState extends ConsumerState<UpcomingScreen>
    with RefreshableList<UpcomingScreen>, TaskListActions<UpcomingScreen> {
  /// The day picked in the strip; null shows the whole range.
  DateTime? _selectedDay;

  @override
  ProviderListenable<Object?> get repositoryProvider => taskRepositoryProvider;

  @override
  void onRepositoryReplaced() {
    super.onRepositoryReplaced();
    clearLeavingTasks();
    _selectedDay = null;
  }

  @override
  Future<void>? startRefresh() =>
      ref.read(taskRepositoryProvider)?.refreshOpenTasks();

  UpcomingPreferences get _preferences =>
      ref.read(upcomingPreferencesProvider).value ??
      const UpcomingPreferences();

  void _save(UpcomingPreferences preferences) =>
      unawaited(ref.read(listPreferencesProvider)?.saveUpcoming(preferences));

  /// Another range shows all of its days.
  void _saveRange(UpcomingPreferences preferences) {
    setState(() => _selectedDay = null);
    _save(preferences);
  }

  Future<void> _chooseRange() async {
    final l10n = context.l10n;
    final current = _preferences;
    final choice = await showOptionSheet<Object>(
      context,
      title: l10n.upcomingSelectRange,
      options: [
        for (final preset in DateRangePreset.values)
          SheetOption(
            value: preset,
            label: presetLabel(l10n, preset),
            selected: current.preset == preset,
          ),
        SheetOption(
          value: _CustomRange.pick,
          label: l10n.upcomingRangeCustomEntry,
          selected: current.preset == null,
        ),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case final DateRangePreset preset:
        _saveRange(current.copyWith(preset: preset));
      case _CustomRange.pick:
        await _chooseCustomRange(current);
    }
  }

  Future<void> _chooseCustomRange(UpcomingPreferences current) async {
    final now = ref.read(clockTickProvider);
    final (first, last) = daysOf(current.range(now));
    final days = await pickDayRange(
      context,
      first: first,
      last: last,
      now: now,
      firstDayOfWeekIndex: ref
          .read(displaySettingsProvider)
          .firstDayOfWeekIndex,
    );
    if (days == null || !mounted) return;
    final (from, to) = days;
    _saveRange(
      current.copyWith(clearPreset: true, customFrom: from, customTo: to),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final storedPreferences = ref.watch(upcomingPreferencesProvider);
    final preferences = storedPreferences.value ?? const UpcomingPreferences();
    // Not the default range for a moment before the stored one.
    final tasks = storedPreferences.isLoading && !storedPreferences.hasValue
        ? const AsyncLoading<List<Task>>()
        : ref.watch(activeOpenTasksProvider);
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final projectsById = {for (final project in projects) project.id: project};
    final now = ref.watch(clockTickProvider);
    final minimumPriority = ref.watch(minimumPriorityProvider);
    final pendingIds =
        ref.watch(pendingTaskIdsProvider).unwrapPrevious().value ?? const {};
    final unread =
        ref.watch(unreadActivityCountProvider).unwrapPrevious().value ?? 0;
    final range = preferences.range(now);
    final name = rangeName(l10n, preferences);
    final dates = rangeDates(context, range, now);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabUpcoming),
        actions: [
          _RangeButton(name: name, dates: dates, onPressed: _chooseRange),
          const SearchButton(),
          // Refresh and the inbox are in the menu, where they leave the
          // title room on a narrow phone; pulling the list refreshes too,
          // and the Overview has the bell.
          PopupMenuButton<_Action>(
            tooltip: l10n.moreActions,
            onSelected: (action) => switch (action) {
              _Action.refresh => unawaited(refresh()),
              _Action.inbox => unawaited(
                GoRouter.of(context).push(AppRoutes.inbox),
              ),
              _Action.toggleOverdue => _save(
                preferences.copyWith(showOverdue: !preferences.showOverdue),
              ),
              _Action.toggleWithoutDueDate => _save(
                preferences.copyWith(
                  showWithoutDueDate: !preferences.showWithoutDueDate,
                ),
              ),
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _Action.refresh,
                enabled: !refreshing,
                child: Text(l10n.refresh),
              ),
              PopupMenuItem(
                value: _Action.inbox,
                child: Text(l10n.inboxButton(unread)),
              ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem(
                value: _Action.toggleOverdue,
                checked: preferences.showOverdue,
                child: Text(l10n.upcomingShowOverdue),
              ),
              CheckedPopupMenuItem(
                value: _Action.toggleWithoutDueDate,
                checked: preferences.showWithoutDueDate,
                child: Text(l10n.upcomingShowWithoutDate),
              ),
            ],
          ),
          const AccountSwitcherButton(),
        ],
        bottom: const SyncProgressBar(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => unawaited(showNewTaskSheet(context)),
        icon: const Icon(Icons.add),
        label: Text(l10n.newTask),
      ),
      body: buildRefreshable(
        tasks,
        loadingLabel: l10n.overviewLoading,
        builder: (value, notice) {
          // A task marked done here stays where it was while its Undo is
          // offered, though the selection skips done tasks.
          final shown = withLeavingTasks(value);
          final shownById = {for (final task in shown) task.id: task};
          final selection = selectUpcoming(
            [
              for (final task in shown)
                if (task.done) task.copyWith(done: false) else task,
            ],
            range: range,
            now: now,
            showOverdue: preferences.showOverdue,
            showWithoutDueDate: preferences.showWithoutDueDate,
          );
          bool open(Task task) => !(shownById[task.id] ?? task).done;
          final byDay = tasksByDay(selection);
          final stripDays = stripDaysOf(range);
          final selectedDay = stripDays?.contains(_selectedDay) ?? false
              ? _selectedDay
              : null;
          final local = now.toLocal();
          return _UpcomingSections(
            sections: switch (selectedDay) {
              null => upcomingSections(selection),
              // Even without tasks, so that it says "Nothing planned"
              // rather than that nothing is upcoming.
              final day => [DaySection(day, byDay[day] ?? const [])],
            },
            shownById: shownById,
            projectsById: projectsById,
            pendingIds: pendingIds,
            now: now,
            minimumPriority: minimumPriority,
            subtitle: l10n.upcomingSubtitle(
              name,
              dates,
              selection.inRange.where(open).length,
            ),
            strip: stripDays == null
                ? null
                : DayStrip(
                    key: ValueKey((stripDays.first, stripDays.last)),
                    days: stripDays,
                    openCounts: {
                      for (final MapEntry(key: day, value: tasks)
                          in byDay.entries)
                        day: tasks.where(open).length,
                    },
                    today: DateTime(local.year, local.month, local.day),
                    selected: selectedDay,
                    onSelected: (day) => setState(() => _selectedDay = day),
                  ),
            notice: notice,
            onDoneChanged: (task, {required done}) =>
                unawaited(setTaskDone(task, done: done)),
            onFavoriteChanged: (task, {required favorite}) =>
                unawaited(setTaskFavorite(task, favorite: favorite)),
          );
        },
      ),
    );
  }
}

/// The app bar's action for the date range, which it names to screen
/// readers.
class _RangeButton extends StatelessWidget {
  const new({required this.name, required this.dates, required this.onPressed});

  final String name;
  final String dates;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      container: true,
      button: true,
      label: l10n.upcomingRangeSemantics(name, dates),
      hint: l10n.upcomingSelectRange,
      onTap: onPressed,
      excludeSemantics: true,
      child: IconButton(
        onPressed: onPressed,
        tooltip: l10n.upcomingSelectRange,
        icon: const Icon(Icons.date_range),
      ),
    );
  }
}

class _UpcomingSections extends StatelessWidget {
  const new({
    required this.sections,
    required this.shownById,
    required this.projectsById,
    required this.pendingIds,
    required this.now,
    required this.minimumPriority,
    required this.subtitle,
    required this.strip,
    required this.notice,
    required this.onDoneChanged,
    required this.onFavoriteChanged,
  });

  final List<UpcomingSection> sections;

  /// The tasks as they show: a task leaving after it was marked done is
  /// its done copy.
  final Map<int, Task> shownById;
  final Map<int, Project> projectsById;
  final Set<int> pendingIds;
  final DateTime now;
  final int minimumPriority;

  /// The range, its days and the open count, above the [strip].
  final String subtitle;

  /// Null for a range too long for it.
  final Widget? strip;

  /// The notice of a failed refresh.
  final Widget? notice;
  final void Function(Task task, {required bool done}) onDoneChanged;
  final void Function(Task task, {required bool favorite}) onFavoriteChanged;

  Widget _row(BuildContext context, Task selected) {
    final l10n = context.l10n;
    final task = shownById[selected.id] ?? selected;
    final project = projectsById[task.projectId];
    return TaskRow(
      key: ValueKey(task.id),
      task: task,
      now: now,
      minimumPriority: minimumPriority,
      projectTitle: project?.displayTitle(l10n),
      projectColor: parseHexColor(project?.hexColor ?? ''),
      pending: pendingIds.contains(task.id),
      onTap: () => unawaited(showTaskDetail(context, task: task)),
      onDoneChanged: (done) => onDoneChanged(task, done: done),
      onFavoriteChanged: (favorite) =>
          onFavoriteChanged(task, favorite: favorite),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final local = now.toLocal();
    final today = DateTime(local.year, local.month, local.day);
    final days = [
      for (final section in sections)
        if (section is DaySection) section,
    ];
    final header = [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        sliver: SliverToBoxAdapter(
          child: Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
      if (strip case final strip?) SliverToBoxAdapter(child: strip),
      if (notice case final notice?) NoticeSliver(notice: notice),
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
    ];
    if (sections.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          ...header,
          SliverFillRemaining(
            hasScrollBody: false,
            child: SafeArea(
              top: false,
              child: Center(
                child: EmptyState(
                  icon: Icons.event_available,
                  title: l10n.upcomingEmptyTitle,
                  body: l10n.upcomingEmptyBody,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        ...header,
        for (final section in sections)
          if (section case OverdueSection(:final tasks))
            SliverSectionCard(
              title: l10n.sectionOverdue,
              count: tasks.length,
              titleColor: Theme.of(context).colorScheme.error,
              itemCount: tasks.length,
              itemBuilder: (context, index) => _row(context, tasks[index]),
            ),
        if (days.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.only(top: 16),
            sliver: SliverList.builder(
              itemCount: days.length,
              itemBuilder: (context, index) {
                final DaySection(:day, :tasks) = days[index];
                return TimelineDay(
                  key: ValueKey(day),
                  day: day,
                  title: dayTitle(context, day, now),
                  today: day == today,
                  rows: [for (final task in tasks) _row(context, task)],
                );
              },
            ),
          ),
        for (final section in sections)
          if (section case WithoutDueDateSection(:final tasks))
            SliverSectionCard(
              title: l10n.sectionNoDueDate,
              count: tasks.length,
              itemCount: tasks.length,
              itemBuilder: (context, index) => _row(context, tasks[index]),
            ),
        // Room for the floating action button below the last row.
        const SliverSafeArea(
          top: false,
          sliver: SliverToBoxAdapter(child: SizedBox(height: 88)),
        ),
      ],
    );
  }
}
