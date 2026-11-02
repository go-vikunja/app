import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_chart.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_grid.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_header.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_overlay.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  // The default range is Oct 11 – Dec 20.
  final now = DateTime(2026, 10, 26, 12);
  late SyncFakes data;
  final listView = sampleListView(id: 11, projectId: 1);
  const gantt = ProjectView(
    id: 12,
    projectId: 1,
    title: 'Gantt',
    kind: ProjectViewKind.gantt,
    position: 200,
  );
  const ganttKey = 'view:12';

  Task stub(int id) => sampleTask(id: id, title: 'Stub $id');

  List<Task> tasks() => [
    sampleTask(
      id: 1,
      title: 'Scheduled',
      start: DateTime(2026, 10, 20, 10),
      end: DateTime(2026, 10, 25, 10),
      hexColor: '1973ff',
    ),
    sampleTask(id: 2, title: 'Starts only', start: DateTime(2026, 11, 1, 9)),
    sampleTask(id: 3, title: 'Ends only', end: DateTime(2026, 11, 5, 10)),
    sampleTask(id: 4, title: 'Due only', due: DateTime(2026, 11, 10, 10)),
    sampleTask(id: 5, title: 'No dates'),
    sampleTask(
      id: 6,
      title: 'Done one',
      start: DateTime(2026, 10, 15, 10),
      end: DateTime(2026, 10, 18, 10),
      done: true,
      doneAt: now,
    ),
    sampleTask(
      id: 7,
      title: 'Parent',
      start: DateTime(2026, 11, 1, 10),
      end: DateTime(2026, 11, 20, 10),
      subtaskIds: [8],
    ),
    sampleTask(
      id: 8,
      title: 'Child',
      start: DateTime(2026, 11, 2, 10),
      end: DateTime(2026, 11, 4, 10),
      parentIds: [7],
    ),
    sampleTask(
      id: 9,
      title: 'Blocker',
      start: DateTime(2026, 10, 27, 10),
      end: DateTime(2026, 10, 29, 10),
      relatedTasks: {
        TaskRelationKind.blocking: [stub(10)],
      },
    ),
    sampleTask(
      id: 10,
      title: 'Blocked',
      start: DateTime(2026, 11, 3, 10),
      end: DateTime(2026, 11, 6, 10),
      relatedTasks: {
        TaskRelationKind.blocked: [stub(9)],
      },
    ),
    sampleTask(
      id: 11,
      title: 'Far away',
      start: DateTime(2027, 3, 1, 10),
      end: DateTime(2027, 3, 5, 10),
    ),
  ];

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(id: 1, title: 'Work', views: [listView, gantt]),
    ];
    data.tasks.all = tasks();
  });

  Future<void> pumpTimeline(
    WidgetTester tester, {
    Size size = const Size(400, 800),
  }) async {
    usePhoneSurface(tester, logicalSize: size);
    await pumpSignedInApp(tester, sync: data, now: now);
    containerOf(tester)
        .read(appRouterProvider)
        .go(AppRoutes.project(1, viewId: gantt.id));
    await tester.pumpAndSettle();
  }

  List<String> rowTitles(WidgetTester tester) => [
    for (final row in tester.widgetList<TimelineRow>(find.byType(TimelineRow)))
      row.row.task.title,
  ];

  TimelineRow rowOf(WidgetTester tester, String title) => tester
      .widgetList<TimelineRow>(find.byType(TimelineRow))
      .firstWhere((row) => row.row.task.title == title);

  Finder rowFinder(String title) => find.byWidgetPredicate(
    (widget) => widget is TimelineRow && widget.row.task.title == title,
  );

  ScrollPosition horizontalOf(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(TimelineChart),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;

  /// Scrolls [finder] into view, sideways too, and taps it.
  Future<void> tapShown(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  IconButton zoomButton(WidgetTester tester, Finder tooltip) =>
      tester.widget<IconButton>(
        find.ancestor(of: tooltip, matching: find.byType(IconButton)),
      );

  TimelinePreferences saved() =>
      (data.listPreferences.views[ganttKey] ?? const ViewPreferences())
          .timeline;

  /// The whole bar of [title]'s row, also where the range cuts it off.
  Rect barOf(WidgetTester tester, String title) {
    final row = rowOf(tester, title);
    final rect = tester.getRect(rowFinder(title));
    final top = rect.top + (row.metrics.rowHeight - row.metrics.barHeight) / 2;
    return Rect.fromLTRB(
      rect.left + row.days.xOf(row.row.bar.column),
      top,
      rect.left + row.days.xOf(row.row.bar.endColumn),
      top + row.metrics.barHeight,
    );
  }

  /// [title]'s row as painted over nothing: the colour at a point given
  /// like `getRect`'s.
  Future<Color Function(Offset point)> rowPixels(
    WidgetTester tester,
    String title,
  ) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find
          .ancestor(
            of: rowFinder(title),
            matching: find.byType(RepaintBoundary),
          )
          .first,
    );
    final origin = tester.getTopLeft(rowFinder(title));
    final width = boundary.size.width.round();
    final bytes = (await tester.runAsync<ByteData?>(() async {
      final image = await boundary.toImage();
      try {
        return await image.toByteData();
      } finally {
        image.dispose();
      }
    }))!;
    Color pixel(Offset point) {
      final local = point - origin;
      final offset = (local.dy.floor() * width + local.dx.floor()) * 4;
      return Color.fromARGB(
        bytes.getUint8(offset + 3),
        bytes.getUint8(offset),
        bytes.getUint8(offset + 1),
        bytes.getUint8(offset + 2),
      );
    }

    return pixel;
  }

  double contrast(Color a, Color b) {
    final (x, y) = (a.computeLuminance(), b.computeLuminance());
    return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
  }

  testWidgets('opens on today in its left third, under a header of months '
      'and days, with the rows of its range', (tester) async {
    await pumpTimeline(tester);

    expect(find.byType(TimelineChart), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('timeline-today')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('timeline-today')),
        matching: find.text('26'),
      ),
      findsOneWidget,
    );
    final chart = tester.getRect(find.byType(TimelineChart));
    final today = tester.getRect(find.byKey(const ValueKey('timeline-today')));
    expect(horizontalOf(tester).pixels, greaterThan(0));
    expect(today.center.dx - chart.left, closeTo(chart.width / 3, 2));

    final titles = rowTitles(tester);
    expect(
      titles,
      containsAll([
        'Scheduled',
        'Starts only',
        'Ends only',
        'Due only',
        'Done one',
        'Parent',
        'Child',
        'Blocker',
        'Blocked',
      ]),
    );
    expect(titles, isNot(contains('No dates')));
    expect(titles, isNot(contains('Far away')));
    expect(titles.indexOf('Child'), titles.indexOf('Parent') + 1);
    // Nothing to download for a view without a filter.
    expect(data.tasks.projectListRefreshes, isEmpty);
  });

  testWidgets('bars by case: the task colour, partial dates, done muted and '
      'struck through, a parent with its chevron', (tester) async {
    await pumpTimeline(tester);

    expect(rowOf(tester, 'Scheduled').row.bar.kind, GanttBarKind.scheduled);
    expect(rowOf(tester, 'Starts only').row.bar.kind, GanttBarKind.startOnly);
    expect(rowOf(tester, 'Ends only').row.bar.kind, GanttBarKind.endOnly);
    expect(rowOf(tester, 'Due only').row.bar.kind, GanttBarKind.endOnly);

    final done = rowFinder('Done one');
    expect(
      tester
          .widget<Text>(
            find.descendant(of: done, matching: find.text('Done one')),
          )
          .style
          ?.decoration,
      TextDecoration.lineThrough,
    );
    // Muted by its colour, not by opacity: see the contrast test.
    expect(
      find.descendant(of: done, matching: find.byType(Opacity)),
      findsNothing,
    );
    // A title that fits sits on its bar in the bar's contrasting colour.
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: rowFinder('Scheduled'),
              matching: find.text('Scheduled'),
            ),
          )
          .style
          ?.color,
      contrastingTextColor(parseHexColor('1973ff')!),
    );
    expect(
      find.byTooltip(en.projectTimelineCollapse('Parent')),
      findsOneWidget,
    );
    expect(find.byTooltip(en.projectTimelineCollapse('Child')), findsNothing);
  });

  testWidgets('the titles and chevrons of tasks in progress show when the '
      'timeline opens, and stay on their bars as it scrolls', (tester) async {
    data.tasks.all = [
      sampleTask(
        id: 1,
        title: 'Quarter',
        start: DateTime(2026, 10, 1, 10),
        end: DateTime(2026, 12, 31, 10),
        subtaskIds: [3],
      ),
      sampleTask(
        id: 2,
        title: 'Week',
        start: DateTime(2026, 10, 21, 10),
        end: DateTime(2026, 11, 1, 10),
      ),
      sampleTask(
        id: 3,
        title: 'Kickoff',
        start: DateTime(2026, 10, 12, 10),
        end: DateTime(2026, 10, 15, 10),
        parentIds: [1],
      ),
    ];
    await pumpTimeline(tester, size: const Size(390, 800));

    final chart = tester.getRect(find.byType(TimelineChart));
    void expectOnScreenOnBar(String title) {
      final text = tester.getRect(find.text(title));
      final bar = barOf(tester, title);
      expect(text.left, greaterThanOrEqualTo(math.max(chart.left, bar.left)));
      expect(text.right, lessThanOrEqualTo(math.min(chart.right, bar.right)));
    }

    expect(horizontalOf(tester).pixels, greaterThan(300));
    expectOnScreenOnBar('Quarter');
    expectOnScreenOnBar('Week');
    final chevron = tester.getRect(
      find.byTooltip(en.projectTimelineCollapse('Quarter')),
    );
    expect(chevron.left, greaterThanOrEqualTo(chart.left));
    expect(
      tester.getRect(find.text('Quarter')).left,
      greaterThanOrEqualTo(chevron.right),
    );

    await tester.drag(find.text('Week'), const Offset(-150, 0));
    await tester.pumpAndSettle();
    expectOnScreenOnBar('Quarter');
    expectOnScreenOnBar('Week');

    horizontalOf(tester).jumpTo(0);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('Week')).left,
      barOf(tester, 'Week').left + TimelineRowMetrics.labelGap,
    );
  });

  testWidgets("a bar cut off by the range's start keeps the fade of the "
      'whole bar: opaque on the days shown', (tester) async {
    // Due on Oct 12 in the afternoon: Oct 5 – 12, opaque from Oct 8.
    data.tasks.all = [
      sampleTask(
        id: 1,
        title: 'Due early',
        due: DateTime(2026, 10, 12, 15),
        hexColor: 'e53935',
      ),
    ];
    await pumpTimeline(tester);
    horizontalOf(tester).jumpTo(0);
    await tester.pumpAndSettle();

    final bar = barOf(tester, 'Due early');
    final chart = tester.getRect(find.byType(TimelineChart));
    expect(bar.left, lessThan(chart.left));
    final pixel = await rowPixels(tester, 'Due early');
    final start = pixel(Offset(chart.left + 4, bar.top + 3));
    expect(start.a, greaterThan(0.99));
    expect(start.r, closeTo(0xe5 / 255, 0.02));
    expect(start.g, closeTo(0x39 / 255, 0.02));
  });

  testWidgets('a partial bar holds its title on its opaque part only; a '
      'longer one goes after the bar', (tester) async {
    data.tasks.all = [
      sampleTask(
        id: 1,
        title: 'Starts later',
        start: DateTime(2026, 10, 27, 9),
        hexColor: '1973ff',
      ),
      sampleTask(
        id: 2,
        title: 'Due tomorrow',
        due: DateTime(2026, 11, 3, 10),
        hexColor: '1973ff',
      ),
      sampleTask(
        id: 3,
        title: 'Due',
        due: DateTime(2026, 11, 10, 10),
        hexColor: '1973ff',
      ),
      sampleTask(
        id: 4,
        title: 'Starts',
        start: DateTime(2026, 11, 2, 9),
        hexColor: '1973ff',
      ),
    ];
    await pumpTimeline(tester);

    for (final title in ['Starts later', 'Due tomorrow']) {
      final bar = barOf(tester, title);
      // Wider than the opaque part, though not than the bar.
      expect(tester.getSize(find.text(title)).width, lessThan(bar.width));
      expect(
        tester.getRect(find.text(title)).left,
        greaterThanOrEqualTo(bar.right),
      );
    }
    final due = barOf(tester, 'Due');
    final dueText = tester.getRect(find.text('Due'));
    expect(dueText.left, greaterThanOrEqualTo(due.left + 0.4 * due.width));
    expect(dueText.right, lessThanOrEqualTo(due.right));
    final starts = barOf(tester, 'Starts');
    final startsText = tester.getRect(find.text('Starts'));
    expect(startsText.left, greaterThanOrEqualTo(starts.left));
    expect(
      startsText.right,
      lessThanOrEqualTo(starts.left + 0.6 * starts.width),
    );
  });

  testWidgets("a done bar's title reads well on its muted colour, in the "
      'dark too', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    data.tasks.all = [
      sampleTask(
        id: 1,
        title: 'Shipped',
        start: DateTime(2026, 10, 24, 10),
        end: DateTime(2026, 10, 29, 10),
        done: true,
        doneAt: now,
        hexColor: '1973ff',
      ),
    ];
    await pumpTimeline(tester);

    final surface = Theme.of(tester.element(find.byType(TimelineChart)))
        .colorScheme
        .surface;
    final bar = barOf(tester, 'Shipped');
    final text = tester.getRect(find.text('Shipped'));
    expect(text.left, greaterThan(bar.left));
    expect(text.right, lessThan(bar.right));
    final pixel = await rowPixels(tester, 'Shipped');
    // What the screen shows: the row over the surface.
    Color shown(Offset point) => Color.alphaBlend(pixel(point), surface);
    final fill = shown(bar.topLeft + const Offset(16, 3));
    final title = shown(text.centerLeft + const Offset(4, 0));
    expect(contrast(title, fill), greaterThan(4.5));
    // Still muted: between its colour and the surface.
    expect(fill, isNot(parseHexColor('1973ff')));
  });

  testWidgets('a pinch zooms without pulling to refresh, also with a finger '
      'moving down; a pull on the rows refreshes', (tester) async {
    await pumpTimeline(tester);

    final centre = tester.getRect(find.byType(TimelineChart)).center;
    final first = await tester.startGesture(centre - const Offset(30, 30));
    await tester.pump(const Duration(milliseconds: 30));
    final second = await tester.startGesture(
      centre + const Offset(30, 30),
      pointer: 7,
    );
    await tester.pump(const Duration(milliseconds: 30));
    for (var step = 1; step <= 10; step++) {
      await first.moveBy(const Offset(-6, -6));
      await second.moveBy(const Offset(6, 30));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(RefreshProgressIndicator), findsNothing);
    }
    await first.up();
    await second.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(saved().dayWidth, greaterThan(TimelinePreferences.defaultDayWidth));
    expect(data.tasks.projectListRefreshes, isEmpty);

    await pullToRefresh(tester, find.byType(TimelineChart));
    expect(data.tasks.projectListRefreshes, [(1, 12)]);
  });

  testWidgets("over the rows: today's line and the blocking arrow; behind "
      'them the day lines and weekends', (tester) async {
    await pumpTimeline(tester);

    final colors = Theme.of(tester.element(find.byType(TimelineChart)))
        .colorScheme;
    final layout = tester
        .widget<TimelineChart>(find.byType(TimelineChart))
        .layout;
    expect(
      [for (final arrow in layout.arrows) (arrow.fromTaskId, arrow.toTaskId)],
      [(9, 10)],
    );
    CustomPaint paintOf(bool Function(CustomPaint paint) test) => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .firstWhere(test);
    final overlay = paintOf(
      (paint) => paint.foregroundPainter is TimelineOverlayPainter,
    );
    final size = tester.getSize(find.byWidget(overlay));
    expect(
      (Canvas canvas) => overlay.foregroundPainter!.paint(canvas, size),
      paints
        ..path(color: colors.error)
        ..path(color: colors.error)
        ..line(color: colors.primary.withValues(alpha: 0.8), strokeWidth: 2),
    );
    final grid = paintOf((paint) => paint.painter is TimelineGridPainter);
    expect(
      (Canvas canvas) =>
          grid.painter!.paint(canvas, tester.getSize(find.byWidget(grid))),
      paints
        ..rect(color: colors.surfaceContainerHighest.withValues(alpha: 0.45))
        ..line(color: colors.outlineVariant.withValues(alpha: 0.6)),
    );
  });

  testWidgets('each row is one screen reader node with its dates, a parent '
      'with its state and the collapse action', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpTimeline(tester);

    String label(String title) => rowOf(tester, title).semanticsLabel;
    expect(
      label('Scheduled'),
      'Scheduled\n'
      '${en.projectTimelineSpanSemantics('Tue, Oct 20', 'Sun, Oct 25')}',
    );
    expect(
      label('Starts only'),
      'Starts only\n${en.projectTimelineStartOnlySemantics('Sun, Nov 1')}',
    );
    expect(
      label('Ends only'),
      'Ends only\n${en.projectTimelineEndOnlySemantics('Thu, Nov 5')}',
    );
    expect(
      label('Due only'),
      'Due only\n${en.projectTimelineDueOnlySemantics('Tue, Nov 10')}',
    );
    expect(
      label('Done one'),
      'Done one\n${en.taskDoneSemantics}\n'
      '${en.projectTimelineSpanSemantics('Thu, Oct 15', 'Sun, Oct 18')}',
    );
    expect(
      label('Child'),
      'Child\n${en.taskSubtaskOfSemantics('Parent')}\n'
      '${en.projectTimelineSpanSemantics('Mon, Nov 2', 'Wed, Nov 4')}',
    );

    final parent = tester.getSemantics(
      find.descendant(
        of: rowFinder('Parent'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == label('Parent'),
        ),
      ),
    );
    expect(
      parent,
      isSemantics(
        label: label('Parent'),
        isButton: true,
        hasTapAction: true,
        hasExpandedState: true,
        isExpanded: true,
        customActions: [
          CustomSemanticsAction(label: en.projectTimelineCollapse('Parent')),
        ],
      ),
    );
    semantics.dispose();
  });

  testWidgets('a blocking arrow is read at both of its ends', (tester) async {
    await pumpTimeline(tester);

    String label(String title) => rowOf(tester, title).semanticsLabel;
    expect(
      label('Blocker'),
      'Blocker\n'
      '${en.projectTimelineSpanSemantics('Tue, Oct 27', 'Thu, Oct 29')}\n'
      '${en.projectTimelineBlocksSemantics('Blocked')}',
    );
    expect(
      label('Blocked'),
      'Blocked\n'
      '${en.projectTimelineSpanSemantics('Tue, Nov 3', 'Fri, Nov 6')}\n'
      '${en.projectTimelineBlockedBySemantics('Blocker')}',
    );
  });

  testWidgets('a precedes arrow is read at both ends, several as a list; a '
      'relation the chart draws no arrow for is not read', (tester) async {
    data.tasks.all = [
      for (final task in tasks())
        if (task.id == 1)
          sampleTask(
            id: 1,
            title: 'Scheduled',
            start: DateTime(2026, 10, 20, 10),
            end: DateTime(2026, 10, 25, 10),
            relatedTasks: {
              TaskRelationKind.precedes: [stub(11)],
            },
          )
        else
          task,
      sampleTask(
        id: 12,
        title: 'First step',
        start: DateTime(2026, 10, 27, 10),
        end: DateTime(2026, 10, 28, 10),
        relatedTasks: {
          TaskRelationKind.precedes: [stub(13), stub(14)],
        },
      ),
      sampleTask(
        id: 13,
        title: 'Second step',
        start: DateTime(2026, 10, 29, 10),
        end: DateTime(2026, 10, 30, 10),
      ),
      sampleTask(
        id: 14,
        title: 'Third step',
        start: DateTime(2026, 10, 29, 10),
        end: DateTime(2026, 10, 31, 10),
      ),
    ];
    await pumpTimeline(tester);

    String lastLine(String title) =>
        rowOf(tester, title).semanticsLabel.split('\n').last;
    expect(
      lastLine('First step'),
      en.projectTimelinePrecedesSemantics('Second step, Third step'),
    );
    expect(
      lastLine('Second step'),
      en.projectTimelineFollowsSemantics('First step'),
    );
    expect(
      lastLine('Third step'),
      en.projectTimelineFollowsSemantics('First step'),
    );
    // "Far away" lies outside the range, so no arrow leads there.
    expect(
      rowOf(tester, 'Scheduled').semanticsLabel,
      'Scheduled\n'
      '${en.projectTimelineSpanSemantics('Tue, Oct 20', 'Sun, Oct 25')}',
    );
  });

  testWidgets('one text above the rows says what day today is and what the '
      'chart shows, for the header that is only drawn', (tester) async {
    await pumpTimeline(tester);

    final summary = find.bySemanticsLabel(
      en.projectTimelineSummarySemantics(
        'Monday, October 26, 2026',
        en.projectTimelineSpanSemantics('Sun, Oct 11', 'Sun, Dec 20'),
      ),
    );
    expect(summary, findsOneWidget);
    final node = tester.getSemantics(summary).getSemanticsData();
    expect(node.hasAction(SemanticsAction.tap), isFalse);
    final chart = tester.getRect(find.byType(TimelineChart));
    final rect = tester.getRect(summary);
    expect(rect.top, chart.top);
    expect(rect.width, chart.width);
    expect(rect.bottom, lessThan(tester.getRect(rowFinder('Scheduled')).top));

    // The header still takes the drag that scrolls the days.
    final position = horizontalOf(tester);
    final before = position.pixels;
    await tester.drag(summary, const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(before));
  });

  testWidgets('a parent hides and shows its subtasks, by its chevron and by '
      "the screen reader's action", (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpTimeline(tester);

    await tapShown(
      tester,
      find.byTooltip(en.projectTimelineCollapse('Parent')),
    );
    expect(rowTitles(tester), isNot(contains('Child')));
    expect(rowOf(tester, 'Parent').collapsed, isTrue);
    // The blocked task's arrow is still drawn: it is not under the parent.
    expect(rowTitles(tester), contains('Blocked'));

    await tapShown(tester, find.byTooltip(en.projectTimelineExpand('Parent')));
    expect(rowTitles(tester), contains('Child'));

    final parentLabel = rowOf(tester, 'Parent').semanticsLabel;
    final node = tester.getSemantics(
      find.descendant(
        of: rowFinder('Parent'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == parentLabel,
        ),
      ),
    );
    final action = CustomSemanticsAction.getIdentifier(
      CustomSemanticsAction(label: en.projectTimelineCollapse('Parent')),
    );
    node.owner!.performAction(node.id, SemanticsAction.customAction, action);
    await tester.pumpAndSettle();
    expect(rowTitles(tester), isNot(contains('Child')));
    semantics.dispose();
  });

  testWidgets('a tap on a row opens the task; a long press does nothing', (
    tester,
  ) async {
    await pumpTimeline(tester);

    await tester.ensureVisible(find.text('Scheduled'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Scheduled'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailSheet), findsNothing);
    expect(data.tasks.writes, isEmpty);

    await tester.tap(find.text('Scheduled'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailSheet), findsOneWidget);
  });

  testWidgets('the range sheet picks a custom range, then the default again, '
      'and resets the range and tasks without dates, not the zoom', (
    tester,
  ) async {
    await pumpTimeline(tester);

    final chip = find.byTooltip(
      en.projectTimelineRangeCurrent('Oct 11 – Dec 20'),
    );
    expect(chip, findsOneWidget);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text(en.projectTimelineRangeTitle), findsOneWidget);
    expect(find.text(en.projectTimelineRangeDefault), findsOneWidget);
    expect(find.text(en.projectTimelineReset), findsNothing);

    await tester.tap(find.text(en.projectTimelineRangeCustom));
    await tester.pumpAndSettle();
    // The first day, then the last, each starting on the shown range's.
    expect(find.text(en.upcomingRangeFrom), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('1')),
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text(en.upcomingRangeTo), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      saved().customRange,
      const GanttRange(
        from: CalendarDate(2026, 10, 1),
        to: CalendarDate(2026, 12, 20),
      ),
    );
    expect(
      find.byTooltip(en.projectTimelineRangeCurrent('Oct 1 – Dec 20')),
      findsOneWidget,
    );
    expect(find.text('October 2026'), findsOneWidget);

    await tester.tap(
      find.byTooltip(en.projectTimelineRangeCurrent('Oct 1 – Dec 20')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.projectTimelineRangeDefault));
    await tester.pumpAndSettle();
    expect(saved().customRange, isNull);

    data.listPreferences.setView(
      ganttKey,
      const ViewPreferences(timeline: TimelinePreferences(dayWidth: 54)),
    );
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text(en.projectTimelineReset), findsNothing);
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();

    data.listPreferences.setView(
      ganttKey,
      const ViewPreferences(
        timeline: TimelinePreferences(withoutDates: true, dayWidth: 54),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.projectTimelineReset));
    await tester.pumpAndSettle();
    expect(saved(), const TimelinePreferences(dayWidth: 54));
  });

  testWidgets('the default range moves on with today while the screen is '
      'open; a custom range stays', (tester) async {
    var current = now;
    usePhoneSurface(tester, logicalSize: const Size(400, 800));
    await pumpSignedInApp(
      tester,
      sync: data,
      overrides: [clockProvider.overrideWithValue(() => current)],
    );
    containerOf(tester)
        .read(appRouterProvider)
        .go(AppRoutes.project(1, viewId: gantt.id));
    await tester.pumpAndSettle();
    expect(
      find.byTooltip(en.projectTimelineRangeCurrent('Oct 11 – Dec 20')),
      findsOneWidget,
    );
    expect(
      data.tasks.projectListRequests.last?.filter,
      ganttFilterText(
        const GanttRange(
          from: CalendarDate(2026, 10, 11),
          to: CalendarDate(2026, 12, 20),
        ),
      ),
    );

    current = DateTime(2026, 10, 27, 0, 0, 30);
    await tester.pump(ClockTick.period);
    await tester.pumpAndSettle();
    expect(
      find.byTooltip(en.projectTimelineRangeCurrent('Oct 12 – Dec 21')),
      findsOneWidget,
    );
    expect(
      data.tasks.projectListRequests.last?.filter,
      ganttFilterText(
        const GanttRange(
          from: CalendarDate(2026, 10, 12),
          to: CalendarDate(2026, 12, 21),
        ),
      ),
    );

    const custom = GanttRange(
      from: CalendarDate(2026, 10, 1),
      to: CalendarDate(2026, 11, 30),
    );
    data.listPreferences.setView(
      ganttKey,
      const ViewPreferences(timeline: TimelinePreferences(customRange: custom)),
    );
    await tester.pumpAndSettle();
    current = DateTime(2026, 10, 28, 0, 0, 30);
    await tester.pump(ClockTick.period);
    await tester.pumpAndSettle();
    expect(
      find.byTooltip(en.projectTimelineRangeCurrent('Oct 1 – Nov 30')),
      findsOneWidget,
    );
    expect(
      data.tasks.projectListRequests.last?.filter,
      ganttFilterText(custom),
    );
  });

  testWidgets('tasks without dates show as estimated bars from today', (
    tester,
  ) async {
    await pumpTimeline(tester);

    await tapShown(
      tester,
      find.widgetWithText(FilterChip, en.projectTimelineShowUndated),
    );

    expect(saved().withoutDates, isTrue);
    expect(rowTitles(tester), contains('No dates'));
    final row = rowOf(tester, 'No dates');
    expect(row.row.bar.kind, GanttBarKind.estimated);
    expect(row.row.bar.first, const CalendarDate(2026, 10, 26));
    expect(
      row.semanticsLabel,
      'No dates\n${en.projectTimelineEstimatedSemantics}',
    );
    expect(
      tester
          .widget<FilterChip>(
            find.widgetWithText(FilterChip, en.projectTimelineShowUndated),
          )
          .selected,
      isTrue,
    );
  });

  testWidgets('the zoom buttons widen and narrow the days within their '
      'bounds, keeping the middle in place', (tester) async {
    await pumpTimeline(tester);

    double dayWidth() =>
        tester.getSize(find.byKey(const ValueKey('timeline-today'))).width;
    final before = horizontalOf(tester).pixels;
    await tapShown(tester, find.byTooltip(en.projectTimelineZoomIn));
    expect(saved().dayWidth, 44);
    expect(horizontalOf(tester).pixels, greaterThan(before));

    for (var i = 0; i < 6; i++) {
      final button = find.byTooltip(en.projectTimelineZoomIn);
      if (zoomButton(tester, button).onPressed == null) break;
      await tapShown(tester, button);
    }
    expect(saved().dayWidth, TimelinePreferences.maxDayWidth);
    expect(
      zoomButton(tester, find.byTooltip(en.projectTimelineZoomIn)).onPressed,
      isNull,
    );
    expect(dayWidth(), greaterThan(0));

    for (var i = 0; i < 10; i++) {
      final button = find.byTooltip(en.projectTimelineZoomOut);
      if (zoomButton(tester, button).onPressed == null) break;
      await tapShown(tester, button);
    }
    expect(saved().dayWidth, TimelinePreferences.minDayWidth);
  });

  testWidgets('two fingers zoom the days; the width is saved when they lift', (
    tester,
  ) async {
    await pumpTimeline(tester);

    final chart = tester.getRect(find.byType(TimelineChart));
    final centre = chart.center;
    final first = await tester.startGesture(centre - const Offset(40, 0));
    final second = await tester.startGesture(
      centre + const Offset(40, 0),
      pointer: 7,
    );
    await tester.pump();
    for (var step = 1; step <= 5; step++) {
      await first.moveBy(const Offset(-8, 0));
      await second.moveBy(const Offset(8, 0));
      await tester.pump();
    }
    expect(saved().dayWidth, TimelinePreferences.defaultDayWidth);
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    // 80 apart, then 160: twice as wide.
    expect(saved().dayWidth, TimelinePreferences.maxDayWidth);
  });

  testWidgets('a pinch while tasks without dates load keeps them on', (
    tester,
  ) async {
    await pumpTimeline(tester);
    data.tasks.holdsProjectList = (request) => request?.includeNulls ?? false;

    await tapShown(
      tester,
      find.widgetWithText(FilterChip, en.projectTimelineShowUndated),
    );
    expect(saved().withoutDates, isTrue);
    // Still the rows from before, while the new ones load.
    expect(find.byType(TimelineChart), findsOneWidget);
    expect(rowTitles(tester), isNot(contains('No dates')));

    final centre = tester.getRect(find.byType(TimelineChart)).center;
    final first = await tester.startGesture(centre - const Offset(40, 0));
    final second = await tester.startGesture(
      centre + const Offset(40, 0),
      pointer: 7,
    );
    await tester.pump();
    for (var step = 1; step <= 5; step++) {
      await first.moveBy(const Offset(-8, 0));
      await second.moveBy(const Offset(8, 0));
      await tester.pump();
    }
    await first.up();
    await second.up();
    await tester.pumpAndSettle();

    expect(
      saved(),
      const TimelinePreferences(
        withoutDates: true,
        dayWidth: TimelinePreferences.maxDayWidth,
      ),
    );
  });

  testWidgets('"Go to today" scrolls back to today', (tester) async {
    await pumpTimeline(tester);

    final position = horizontalOf(tester);
    final atToday = position.pixels;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('timeline-today')), findsNothing);

    await tapShown(tester, find.byTooltip(en.projectTimelineGoToToday));
    expect(position.pixels, closeTo(atToday, 0.5));
    expect(find.byKey(const ValueKey('timeline-today')), findsOneWidget);
  });

  testWidgets('"Go to today" jumps there under Reduce Motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          reduceMotion: true,
          supportsAnnounce: true,
        );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpTimeline(tester);

    final position = horizontalOf(tester);
    final atToday = position.pixels;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    final button = find.byTooltip(en.projectTimelineGoToToday);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();

    await tester.tap(button);
    await tester.pump();
    expect(position.pixels, closeTo(atToday, 0.5));
  });

  testWidgets('a range without tasks says so and how to find some', (
    tester,
  ) async {
    data.listPreferences.setView(
      ganttKey,
      const ViewPreferences(
        timeline: TimelinePreferences(
          customRange: GanttRange(
            from: CalendarDate(2025, 1, 1),
            to: CalendarDate(2025, 1, 31),
          ),
        ),
      ),
    );
    await pumpTimeline(tester);

    expect(find.byType(TimelineChart), findsNothing);
    expect(
      find.text(en.projectTimelineEmptyTitle('Jan 1, 2025', 'Jan 31, 2025')),
      findsOneWidget,
    );
    expect(find.text(en.projectTimelineEmptyBody), findsOneWidget);
    // Out of today's range: no way back to it.
    expect(
      zoomButton(tester, find.byTooltip(en.projectTimelineGoToToday)).onPressed,
      isNull,
    );

    data.listPreferences.setView(
      ganttKey,
      const ViewPreferences(
        timeline: TimelinePreferences(
          customRange: GanttRange(
            from: CalendarDate(2025, 1, 1),
            to: CalendarDate(2025, 1, 31),
          ),
          withoutDates: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(en.projectTimelineEmptyRangeBody), findsOneWidget);
  });

  testWidgets('a filter only the server evaluates: downloading, offline, '
      'then the downloaded tasks of the range under a note', (tester) async {
    const filtered = ProjectView(
      id: 12,
      projectId: 1,
      title: 'Gantt',
      kind: ProjectViewKind.gantt,
      position: 200,
      filter: ViewFilter(filter: 'bucket_id = 3'),
    );
    data.projects.all = [
      sampleProject(id: 1, title: 'Work', views: [listView, filtered]),
    ];
    data.tasks
      ..snapshotOnlyViews.add(12)
      ..refreshProjectListFailure = const NetworkFailure(
        NetworkProblem.unreachable,
      );
    await pumpTimeline(tester);

    expect(find.text(en.projectViewNotLoadedTitle), findsOneWidget);
    expect(
      find.text(en.projectViewNotLoadedBody('bucket_id = 3')),
      findsOneWidget,
    );
    expect(data.tasks.projectListRefreshes, [(1, 12)]);

    data.tasks.setSnapshot(
      ganttKey,
      ListSnapshot(positions: const {1: 1, 11: 2}, loadedAt: now),
    );
    await tester.pumpAndSettle();
    expect(rowTitles(tester), ['Scheduled']);
    expect(
      find.text(en.projectViewFilterNotice('bucket_id = 3', en.relativeNow)),
      findsOneWidget,
    );
  });

  testWidgets('a range of decades builds the header days on screen only, '
      'from the first frame', (tester) async {
    data.listPreferences.setView(
      ganttKey,
      const ViewPreferences(
        timeline: TimelinePreferences(
          customRange: GanttRange(
            from: CalendarDate(2016, 1, 1),
            to: CalendarDate(2036, 12, 31),
          ),
        ),
      ),
    );
    usePhoneSurface(tester, logicalSize: const Size(400, 800));
    await pumpSignedInApp(tester, sync: data, now: now);
    containerOf(tester)
        .read(appRouterProvider)
        .go(AppRoutes.project(1, viewId: gantt.id));

    final dayCells = find.descendant(
      of: find.byType(TimelineHeader),
      matching: find.byWidgetPredicate(
        (widget) => widget is Positioned && widget.key is ValueKey<int>,
      ),
    );
    var most = 0;
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      most = math.max(most, dayCells.evaluate().length);
    }
    expect(find.byKey(const ValueKey('timeline-today')), findsOneWidget);
    expect(most, inInclusiveRange(1, 40));
  });

  testWidgets('a German timeline names its months and days in German', (
    tester,
  ) async {
    useLocale(tester, const Locale('de'));
    await pumpTimeline(tester);

    expect(find.text('Oktober 2026'), findsOneWidget);
    expect(
      find.byTooltip(de.projectTimelineRangeCurrent('11. Okt. – 20. Dez.')),
      findsOneWidget,
    );
    expect(TimelineHeader.maxTextScale, 1.5);
  });
}
