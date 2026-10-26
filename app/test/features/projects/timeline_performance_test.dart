import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/core/filters/filter_zone.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/time/today_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/project_timeline_body.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_chart.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_row.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';

// A large project on a phone: the timeline's layout is computed once per
// source and the first frame builds only the rows on screen.
void main() {
  final today = DateTime(2026, 10, 26);
  const view = ProjectView(
    id: 12,
    projectId: 1,
    title: 'Gantt',
    kind: ProjectViewKind.gantt,
    position: 200,
  );

  /// Every tenth task has three subtasks, every seventeenth blocks the
  /// next; the dates cover the default range with every kind of bar.
  List<Task> synthetic(int count) {
    final first = today.subtract(const Duration(days: 20));
    return [
      for (var id = 1; id <= count; id++)
        () {
          final start = first.add(Duration(days: id % 80, hours: 9));
          final end = start.add(Duration(days: id % 9 + 1));
          final parent = id % 10 == 1 ? null : id - (id - 1) % 10;
          final hasChildren = id % 10 == 1 && id + 3 <= count;
          return sampleTask(
            id: id,
            title: 'Task number $id with a title',
            start: id % 13 == 0 || id % 11 == 0 ? null : start,
            end: id % 7 == 0 || id % 13 == 0 ? null : end,
            due: id % 11 == 0 ? end : null,
            done: id % 5 == 0,
            doneAt: id % 5 == 0 ? today : null,
            hexColor: id % 3 == 0 ? 'e8445a' : '',
            subtaskIds: hasChildren ? [id + 1, id + 2, id + 3] : const [],
            parentIds: parent != null && (id - 1) % 10 <= 3
                ? [parent]
                : const [],
            relatedTasks: {
              if (id % 17 == 0 && id < count)
                TaskRelationKind.blocking: [sampleTask(id: id + 1, title: '')],
            },
          );
        }(),
    ];
  }

  ProjectListSource sourceOf(List<Task> tasks) => ProjectListSource(
    projectTasks: tasks,
    tasksById: {for (final task in tasks) task.id: task},
    matchingIds: {for (final task in tasks) task.id},
  );

  Widget app(ProjectListSource source, {double dayWidth = 36}) => ProviderScope(
    overrides: [todayProvider.overrideWithValue(today)],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: Scaffold(
        body: ProjectTimelineBody(
          view: view,
          source: source,
          preferences: ViewPreferences(
            timeline: TimelinePreferences(
              withoutDates: true,
              dayWidth: dayWidth,
            ),
          ),
          offline: false,
          downloadFailed: false,
          header: null,
        ),
      ),
    ),
  );

  testWidgets('1,000 tasks: the first frame builds the rows on screen only, '
      'within a budget, and a zoom keeps the layout', (tester) async {
    usePhoneSurface(tester);
    final source = sourceOf(synthetic(1000));
    // The zone database, the first layout's compilation and the app's
    // first frame are not what is measured.
    deviceLocation();
    int layoutMilliseconds() {
      final watch = Stopwatch()..start();
      layoutGantt(
        matching: source.projectTasks,
        tasksById: source.tasksById,
        range: defaultGanttRange(today),
        today: CalendarDate.of(today),
        zone: deviceLocation(),
        showTasksWithoutDates: true,
      );
      return (watch..stop()).elapsedMilliseconds;
    }

    layoutMilliseconds();
    final model = [for (var i = 0; i < 3; i++) layoutMilliseconds()]
        .reduce((a, b) => a < b ? a : b);
    await tester.pumpWidget(app(sourceOf(const [])));

    final watch = Stopwatch()..start();
    await tester.pumpWidget(app(source));
    watch.stop();

    final layout = tester
        .widget<TimelineChart>(find.byType(TimelineChart))
        .layout;
    // The number the step reports.
    // ignore: avoid_print
    print(
      'Timeline of ${layout.rows.length} rows laid out in $model ms, its '
      'first frame in ${watch.elapsedMilliseconds} ms',
    );
    expect(layout.rows.length, greaterThan(800));
    expect(layout.arrows, isNotEmpty);
    expect(find.byType(TimelineRow).evaluate().length, lessThan(30));
    expect(model, lessThan(40));
    // Debug mode: building every row instead would take seconds.
    expect(watch.elapsedMilliseconds, lessThan(600));

    await tester.pumpWidget(app(source, dayWidth: 54));
    await tester.pumpAndSettle();
    expect(
      identical(
        tester.widget<TimelineChart>(find.byType(TimelineChart)).layout,
        layout,
      ),
      isTrue,
    );

    final rows = find
        .descendant(
          of: find.byType(TimelineChart),
          matching: find.byType(Scrollable),
        )
        .last;
    final vertical = tester.state<ScrollableState>(rows).position;
    vertical.jumpTo(vertical.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.byType(TimelineRow).evaluate().length, lessThan(30));
    expect(
      tester
          .widgetList<TimelineRow>(find.byType(TimelineRow))
          .map((row) => row.row.task.id),
      contains(layout.rows.last.task.id),
    );
  });
}
