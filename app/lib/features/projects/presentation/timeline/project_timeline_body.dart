import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/core/filters/filter_zone.dart';
import 'package:vikunja_mobile/core/filters/local_filters.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/core/time/today_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/list_note.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_view_labels.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_chart.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_controls.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_pane.dart';

/// A Gantt view's body: the timeline of the tasks in its range, laid out
/// once per source, range, day and collapsed rows; or why there is none:
/// nothing in the range, or a filter only the server can evaluate that
/// was never downloaded. Under such a filter the tasks are its last
/// download's, which a note says.
class ProjectTimelineBody extends ConsumerStatefulWidget {
  const new({
    required this.view,
    required this.source,
    required this.preferences,
    required this.offline,
    required this.downloadFailed,
    required this.header,
    this.bottomPadding = 0,
    super.key,
  });

  final ProjectView view;

  /// From `timelineSourceProvider`: `matchingIds` are the tasks of the
  /// range.
  final ProjectListSource source;
  final ViewPreferences preferences;

  /// The device is offline, as far as the last sync or download knows.
  final bool offline;

  /// The view's download failed for a reason other than the connection.
  final bool downloadFailed;

  /// The controls and notes above the timeline.
  final Widget? header;

  /// Below the last row, to scroll it clear of a floating action button.
  final double bottomPadding;

  @override
  ConsumerState<ProjectTimelineBody> createState() =>
      _ProjectTimelineBodyState();
}

class _ProjectTimelineBodyState extends ConsumerState<ProjectTimelineBody> {
  /// Not kept: every parent starts expanded, as on the web.
  final _collapsed = <int>{};
  var _collapsedChanges = 0;
  final _pinching = ValueNotifier<bool>(false);

  GanttLayout? _layout;
  Object? _layoutKey;

  GanttLayout _layoutFor(GanttRange range, CalendarDate today) {
    final source = widget.source;
    final withoutDates = widget.preferences.timeline.withoutDates;
    final key = (source, range, today, withoutDates, _collapsedChanges);
    final cached = _layout;
    if (cached != null && key == _layoutKey) return cached;
    final matchingIds = source.matchingIds;
    _layoutKey = key;
    return _layout = layoutGantt(
      matching: [
        for (final task in source.projectTasks)
          if (matchingIds == null || matchingIds.contains(task.id)) task,
      ],
      tasksById: source.tasksById,
      range: range,
      today: today,
      zone: deviceLocation(),
      showTasksWithoutDates: withoutDates,
      collapsed: _collapsed,
    );
  }

  @override
  void dispose() {
    _pinching.dispose();
    super.dispose();
  }

  void _toggle(int taskId) => setState(() {
    if (!_collapsed.remove(taskId)) _collapsed.add(taskId);
    _collapsedChanges++;
  });

  void _saveDayWidth(double width) {
    final listKey = listKeyFor(
      projectId: widget.view.projectId,
      viewId: widget.view.id,
    );
    // Not widget.preferences: while a new range or "without dates" loads,
    // they are still the previous ones, and saving them would undo it.
    final preferences =
        ref.read(viewPreferencesProvider(listKey)).value ?? widget.preferences;
    unawaited(
      ref
          .read(listPreferencesProvider)
          ?.saveView(
            listKey,
            preferences.copyWith(
              timeline: preferences.timeline.copyWith(dayWidth: width),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final todayMidnight = ref.watch(todayProvider);
    final today = CalendarDate.of(todayMidnight);
    final timeline = widget.preferences.timeline;
    final range = timeline.range(todayMidnight);
    final source = widget.source;
    final view = widget.view;
    final downloads = downloadsSnapshot(view);
    final loadedAt = source.snapshot.loadedAt;
    final Widget? header;
    if (downloads && loadedAt != null) {
      final now = ref.watch(clockTickProvider);
      header = stackedNotes([
        ?widget.header,
        ListNote(
          icon: Icons.filter_alt_outlined,
          text: l10n.projectViewFilterNotice(
            describeViewFilter(view.filter),
            formatRelativeTime(
              l10n,
              // The tick may lag behind a download just finished.
              loadedAt.isAfter(now) ? now : loadedAt,
              now: now,
            ),
          ),
        ),
      ]);
    } else {
      header = widget.header;
    }

    if (downloads && loadedAt == null) {
      final filter = describeViewFilter(view.filter);
      return CenteredScrollView(
        header: header,
        maxWidth: ReadableWidth.list,
        child: switch ((widget.offline, widget.downloadFailed)) {
          (true, _) => EmptyState(
            icon: Icons.cloud_download_outlined,
            title: l10n.projectViewNotLoadedTitle,
            body: l10n.projectViewNotLoadedBody(filter),
          ),
          (_, true) => EmptyState(
            icon: Icons.cloud_off_outlined,
            title: l10n.projectViewDownloadFailedTitle,
            body: l10n.projectViewDownloadFailedBody(filter),
          ),
          _ => EmptyState(
            icon: Icons.cloud_download_outlined,
            title: l10n.projectViewDownloadingTitle,
            body: l10n.projectViewDownloadingBody(filter),
          ),
        },
      );
    }

    final layout = _layoutFor(range, today);
    if (layout.isEmpty) {
      final (from, to) = timelineRangeDays(
        context,
        range,
        today: todayMidnight,
      );
      return CenteredScrollView(
        header: header,
        maxWidth: ReadableWidth.list,
        child: EmptyState(
          icon: Icons.view_timeline_outlined,
          title: l10n.projectTimelineEmptyTitle(from, to),
          body: timeline.withoutDates
              ? l10n.projectTimelineEmptyRangeBody
              : l10n.projectTimelineEmptyBody,
        ),
      );
    }

    final slivers = [
      // The controls under the tabs, the timeline at the whole width.
      if (header != null)
        SliverReadableWidth(
          maxWidth: ReadableWidth.list,
          sliver: NoticeSliver(notice: header),
        ),
      SliverLayoutBuilder(
        builder: (context, sliver) => SliverToBoxAdapter(
          child: SizedBox(
            height: timelineChartHeight(
              math.max(
                sliver.viewportMainAxisExtent - sliver.precedingScrollExtent,
                0,
              ),
              context,
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TimelineChart(
                // A new range opens on today again.
                key: ValueKey((view.id, range)),
                viewId: view.id,
                layout: layout,
                dayWidth: timeline.dayWidth,
                bottomPadding: widget.bottomPadding,
                onOpen: (task) => openTaskDetail(context, task: task),
                onToggleCollapsed: _toggle,
                onDayWidthChanged: _saveDayWidth,
                onPinchChanged: (pinching) {
                  if (mounted) _pinching.value = pinching;
                },
              ),
            ),
          ),
        ),
      ),
    ];
    return ValueListenableBuilder(
      valueListenable: _pinching,
      builder: (context, pinching, _) => CustomScrollView(
        physics: pinching
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        slivers: slivers,
      ),
    );
  }
}
