import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_switcher_button.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/list_note.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/common/presentation/option_sheet.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/inbox/presentation/inbox_button.dart';
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

enum _Action { refresh, toggleOverdue, toggleWithoutDueDate }

enum _CustomRange { pick }

/// The open tasks due in a date range, by day, below the overdue ones; the
/// web's Upcoming with the web's date-range presets.
class UpcomingScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<UpcomingScreen> createState() => _UpcomingScreenState();
}

class _UpcomingScreenState extends ConsumerState<UpcomingScreen>
    with RefreshableList<UpcomingScreen>, TaskListActions<UpcomingScreen> {
  // Keeps the button, and its focus, between the loading and list states.
  final GlobalKey _rangeButtonKey = GlobalKey();

  @override
  ProviderListenable<Object?> get repositoryProvider => taskRepositoryProvider;

  @override
  void onRepositoryReplaced() {
    super.onRepositoryReplaced();
    clearLeavingTasks();
  }

  @override
  Future<void>? startRefresh() =>
      ref.read(taskRepositoryProvider)?.refreshOpenTasks();

  UpcomingPreferences get _preferences =>
      ref.read(upcomingPreferencesProvider).value ??
      const UpcomingPreferences();

  void _save(UpcomingPreferences preferences) =>
      unawaited(ref.read(listPreferencesProvider)?.saveUpcoming(preferences));

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
        _save(current.copyWith(preset: preset));
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
    _save(current.copyWith(clearPreset: true, customFrom: from, customTo: to));
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
    final range = preferences.range(now);
    final rangeButton = _RangeButton(
      key: _rangeButtonKey,
      name: rangeName(l10n, preferences),
      dates: rangeDates(context, range, now),
      onPressed: _chooseRange,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabUpcoming),
        actions: [
          // Refresh is in the menu, where it leaves the title room on a
          // narrow phone; pulling the list refreshes too.
          const SearchButton(),
          const InboxButton(),
          const AccountSwitcherButton(),
          PopupMenuButton<_Action>(
            tooltip: l10n.moreActions,
            onSelected: (action) => switch (action) {
              _Action.refresh => unawaited(refresh()),
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
        ],
        bottom: const SyncProgressBar(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => unawaited(showNewTaskSheet(context)),
        icon: const Icon(Icons.add),
        label: Text(l10n.newTask),
      ),
      // The range button scrolls with the list: pinned above it, at large
      // text in landscape it would leave room for about one row.
      body: buildRefreshable(
        tasks,
        loadingLabel: l10n.overviewLoading,
        header: rangeButton,
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
          return _UpcomingSections(
            sections: upcomingSections(selection),
            shownById: shownById,
            projectsById: projectsById,
            pendingIds: pendingIds,
            now: now,
            minimumPriority: minimumPriority,
            header: stackedNotes([rangeButton, ?notice])!,
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

class _RangeButton extends StatelessWidget {
  const new({
    required this.name,
    required this.dates,
    required this.onPressed,
    super.key,
  });

  final String name;
  final String dates;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      button: true,
      label: context.l10n.upcomingRangeSemantics(name, dates),
      hint: context.l10n.upcomingSelectRange,
      onTap: onPressed,
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          alignment: AlignmentDirectional.centerStart,
        ),
        child: Row(
          children: [
            Icon(Icons.date_range, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.titleSmall),
                  Text(
                    dates,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: colors.onSurfaceVariant),
          ],
        ),
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
    required this.header,
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

  /// The range button, and below it the notice of a failed refresh.
  final Widget header;
  final void Function(Task task, {required bool done}) onDoneChanged;
  final void Function(Task task, {required bool favorite}) onFavoriteChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (sections.isEmpty) {
      return CenteredScrollView(
        header: header,
        child: EmptyState(
          icon: Icons.event_available,
          title: l10n.upcomingEmptyTitle,
          body: l10n.upcomingEmptyBody,
        ),
      );
    }
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        NoticeSliver(notice: header),
        for (final section in sections) ...[
          SliverToBoxAdapter(
            child: ListSectionHeader(
              title: switch (section) {
                OverdueSection() => l10n.sectionOverdue,
                DaySection(:final day) => dayTitle(context, day, now),
                WithoutDueDateSection() => l10n.sectionNoDueDate,
              },
              count: section.tasks.length,
            ),
          ),
          SliverList.builder(
            itemCount: section.tasks.length,
            itemBuilder: (context, index) {
              final selected = section.tasks[index];
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
            },
          ),
        ],
        // Room for the floating action button below the last row.
        const SliverSafeArea(
          top: false,
          sliver: SliverToBoxAdapter(child: SizedBox(height: 88)),
        ),
      ],
    );
  }
}
