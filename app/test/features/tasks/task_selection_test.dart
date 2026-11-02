import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/board_card.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_row.dart';
import 'package:vikunja_mobile/features/search/presentation/search_page.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/label_tasks_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relations/relation_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/selected_task_highlight.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_pane.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

import '../../a11y/sweep_data.dart';
import '../../helpers/large_screens.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';

const _iOS = TargetPlatformVariant({TargetPlatform.iOS});

Finder _taskRow(String title) => find.widgetWithText(TaskRow, title);

Finder _card(String title) => find.widgetWithText(BoardCard, title);

Finder _timelineRow(String title) => find.widgetWithText(TimelineRow, title);

Finder _inPane(Finder matching) =>
    find.descendant(of: find.byType(TaskDetailPane), matching: matching);

ColorScheme _colors(WidgetTester tester, Finder surface) =>
    Theme.of(tester.element(surface)).colorScheme;

Finder _highlight(Finder surface) => find
    .descendant(of: surface, matching: find.byType(SelectedTaskHighlight))
    .first;

Decoration? _highlightDecoration(WidgetTester tester, Finder surface) => tester
    .widget<Ink>(
      find
          .descendant(of: _highlight(surface), matching: find.byType(Ink))
          .first,
    )
    .decoration;

Tristate _semanticsSelected(
  WidgetTester tester,
  Finder surface,
  String title,
) => tester
    .getSemantics(find.descendant(of: surface, matching: find.text(title)))
    .getSemanticsData()
    .flagsCollection
    .isSelected;

int? _paneTaskId(WidgetTester tester) => tester
    .widget<TaskDetailPaneScope>(find.byType(TaskDetailPaneScope))
    .selectedTaskId;

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// The pane's one related task, opened inside it.
Future<void> _openRelated(WidgetTester tester) async {
  final related = _inPane(find.byType(RelationRow));
  await tester.scrollUntilVisible(
    related,
    200,
    scrollable: _inPane(find.byType(Scrollable)).first,
  );
  // Clear of the comment composer below the list.
  await Scrollable.ensureVisible(tester.element(related), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(related);
  await tester.pumpAndSettle();
}

Future<void> _tapRow(WidgetTester tester, String title) => _tap(
  tester,
  find.descendant(of: _taskRow(title), matching: find.text(title)),
);

/// The row of [title] and its highlight say alike whether it is selected,
/// in the A8 colours.
void _expectRow(WidgetTester tester, String title, {required bool selected}) {
  final row = _taskRow(title);
  final colors = _colors(tester, row);
  expect(
    tester.widget<SelectedTaskHighlight>(_highlight(row)).selected,
    selected,
    reason: title,
  );
  expect(
    _highlightDecoration(tester, row),
    selected
        ? SelectedTaskDecoration(
            fill: colors.surfaceContainerHighest,
            indicator: colors.primary,
          )
        : isNull,
    reason: title,
  );
  expect(
    _semanticsSelected(tester, row, title),
    selected ? Tristate.isTrue : Tristate.none,
    reason: title,
  );
}

void _expectNoRowSelected(WidgetTester tester) {
  for (final highlight in tester.widgetList<SelectedTaskHighlight>(
    find.byType(SelectedTaskHighlight),
  )) {
    expect(highlight.selected, isFalse);
  }
}

Future<void> _openView(WidgetTester tester, int viewId) async {
  await pumpSweepApp(tester);
  goTo(tester, AppRoutes.project(workProjectId, viewId: viewId));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the Overview row of the task in the pane is selected, and the '
      'selection moves with the task and goes with the pane', (tester) async {
    useWindow(tester, androidTabletLandscape);
    final semantics = tester.ensureSemantics();
    await pumpSweepApp(tester);
    _expectRow(tester, 'Call the plumber', selected: false);
    _expectRow(tester, 'Buy seeds', selected: false);

    await _tapRow(tester, 'Call the plumber');
    expect(_paneTaskId(tester), 1);
    _expectRow(tester, 'Call the plumber', selected: true);
    _expectRow(tester, 'Buy seeds', selected: false);

    // Painted on the section card, under the row.
    final row = _taskRow('Call the plumber');
    final colors = _colors(tester, row);
    final card = find.ancestor(of: row, matching: find.byType(Material)).first;
    final rect = tester.getRect(row).shift(-tester.getTopLeft(card));
    expect(
      tester.renderObject(card),
      paints
        ..rect(rect: rect, color: colors.surfaceContainerHighest)
        ..rect(
          rect: Rect.fromLTWH(rect.left, rect.top, 4, rect.height),
          color: colors.primary,
        ),
    );

    await _tapRow(tester, 'Buy seeds');
    expect(_paneTaskId(tester), 2);
    _expectRow(tester, 'Call the plumber', selected: false);
    _expectRow(tester, 'Buy seeds', selected: true);

    await tester.tap(_inPane(find.byTooltip(en.taskDetailClose)));
    await tester.pumpAndSettle();
    _expectNoRowSelected(tester);
    _expectRow(tester, 'Buy seeds', selected: false);
    semantics.dispose();
  });

  for (final (name, open, title, other)
      in <(String, Future<void> Function(WidgetTester), String, String)>[
        (
          'Upcoming',
          (tester) async {
            await pumpSweepApp(tester);
            goTo(tester, AppRoutes.upcoming);
            await tester.pumpAndSettle();
          },
          'Write the report',
          'Buy seeds',
        ),
        (
          'Favourites',
          (tester) async {
            await pumpSweepApp(tester);
            goTo(tester, AppRoutes.project(Project.favoritesId));
            await tester.pumpAndSettle();
          },
          'Read the contract',
          'Call the plumber',
        ),
        (
          "a project's list",
          (tester) => _openView(tester, listViewId),
          'Plan the team day',
          'Write the report',
        ),
        (
          "a project's table",
          (tester) => _openView(tester, tableViewId),
          'Plan the team day',
          'Write the report',
        ),
      ]) {
    testWidgets('in $name the row of the task in the pane is selected', (
      tester,
    ) async {
      useWindow(tester, androidTabletLandscape);
      final semantics = tester.ensureSemantics();
      await open(tester);

      await _tapRow(tester, title);
      expect(find.byType(TaskDetailPane), findsOneWidget);
      _expectRow(tester, title, selected: true);
      _expectRow(tester, other, selected: false);
      semantics.dispose();
    });
  }

  testWidgets('a related task opened in the pane takes the selection, and '
      'back gives it back', (tester) async {
    useWindow(tester, androidTabletLandscape);
    final semantics = tester.ensureSemantics();
    await _openView(tester, listViewId);

    await _tapRow(tester, 'Plan the team day');
    _expectRow(tester, 'Plan the team day', selected: true);

    await _openRelated(tester);
    expect(_paneTaskId(tester), 3);
    _expectRow(tester, 'Write the report', selected: true);
    _expectRow(tester, 'Plan the team day', selected: false);

    await tester.tap(_inPane(find.byType(BackButtonIcon)));
    await tester.pumpAndSettle();
    expect(_paneTaskId(tester), 4);
    _expectRow(tester, 'Plan the team day', selected: true);
    _expectRow(tester, 'Write the report', selected: false);
    semantics.dispose();
  });

  testWidgets('a related task that is not in the list leaves no row '
      'selected', (tester) async {
    useWindow(tester, androidTabletLandscape);
    final data = sweepData();
    data.tasks.all = [
      for (final task in data.tasks.all)
        if (task.id == 6)
          sampleTask(
            id: 6,
            title: task.title,
            due: task.dueDate,
            favorite: true,
            relatedTasks: {
              TaskRelationKind.related: [
                sampleTask(id: 3, title: 'Write the report'),
              ],
            },
          )
        else
          task,
    ];
    await pumpSweepApp(tester, data: data);
    goTo(tester, AppRoutes.project(Project.favoritesId));
    await tester.pumpAndSettle();
    expect(_taskRow('Write the report'), findsNothing);

    await _tapRow(tester, 'Read the contract');
    _expectRow(tester, 'Read the contract', selected: true);
    await _openRelated(tester);
    expect(_paneTaskId(tester), 3);
    _expectNoRowSelected(tester);
  });

  testWidgets('the board card of the task in the pane is selected, with an '
      'outline along its corners', (tester) async {
    useWindow(tester, androidTabletLandscape);
    final semantics = tester.ensureSemantics();
    await _openView(tester, kanbanViewId);

    await _tap(tester, _card('Call the plumber'));
    expect(_paneTaskId(tester), 1);
    final card = _card('Call the plumber');
    final colors = _colors(tester, card);
    expect(
      tester.widget<SelectedTaskHighlight>(_highlight(card)).selected,
      isTrue,
    );
    expect(
      _highlightDecoration(tester, card),
      SelectedTaskDecoration(
        fill: colors.surfaceContainerHighest,
        indicator: colors.primary,
        cardRadius: const Radius.circular(12),
      ),
    );
    expect(
      _semanticsSelected(tester, card, 'Call the plumber'),
      Tristate.isTrue,
    );
    final other = _card('Write the report');
    expect(
      tester.widget<SelectedTaskHighlight>(_highlight(other)).selected,
      isFalse,
    );
    expect(_highlightDecoration(tester, other), isNull);
    expect(
      _semanticsSelected(tester, other, 'Write the report'),
      Tristate.none,
    );

    await _tap(tester, other);
    expect(
      tester.widget<SelectedTaskHighlight>(_highlight(other)).selected,
      isTrue,
    );
    expect(
      _semanticsSelected(tester, other, 'Write the report'),
      Tristate.isTrue,
    );
    expect(
      tester.widget<SelectedTaskHighlight>(_highlight(card)).selected,
      isFalse,
    );
    expect(_semanticsSelected(tester, card, 'Call the plumber'), Tristate.none);
    semantics.dispose();
  });

  testWidgets('the timeline row of the task in the pane is tinted and its bar '
      'outlined', (tester) async {
    useWindow(tester, androidTabletLandscape);
    final semantics = tester.ensureSemantics();
    await _openView(tester, ganttViewId);

    Color? band(String title) =>
        (tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: _timelineRow(title),
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration)
            .color;
    Finder bar(String title) => find
        .descendant(
          of: _timelineRow(title),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint &&
                widget.painter.runtimeType.toString() == '_BarPainter',
          ),
        )
        .first;

    await _tap(
      tester,
      find.descendant(
        of: _timelineRow('Write the report'),
        matching: find.text('Write the report'),
      ),
    );
    expect(_paneTaskId(tester), 3);
    final colors = _colors(tester, _timelineRow('Write the report'));
    // The chart's day lines and weekends show through it.
    final tint = colors.surfaceContainerHighest.withValues(alpha: 0.6);
    expect(band('Write the report'), tint);
    expect(
      _semanticsSelected(
        tester,
        _timelineRow('Write the report'),
        'Write the report',
      ),
      Tristate.isTrue,
    );
    // Around the bar, meeting it at its edge, 1 dp inside the box.
    expect(
      tester.renderObject(bar('Write the report')),
      paints
        ..rrect()
        ..rrect(
          rrect: RRect.fromRectAndRadius(
            Offset.zero & tester.getSize(bar('Write the report')),
            const Radius.circular(7),
          ),
          color: colors.primary,
          strokeWidth: 2,
          style: PaintingStyle.stroke,
        ),
    );
    expect(band('Plan the team day'), isNull);
    expect(
      _semanticsSelected(
        tester,
        _timelineRow('Plan the team day'),
        'Plan the team day',
      ),
      Tristate.none,
    );
    expect(
      tester.renderObject(bar('Plan the team day')),
      paintsExactlyCountTimes(#drawRRect, 1),
    );

    await _tap(
      tester,
      find.descendant(
        of: _timelineRow('Plan the team day'),
        matching: find.text('Plan the team day'),
      ),
    );
    expect(_paneTaskId(tester), 4);
    expect(band('Plan the team day'), tint);
    expect(band('Write the report'), isNull);
    semantics.dispose();
  });

  testWidgets('on an iPad the row of the task in the pane is selected', (
    tester,
  ) async {
    useWindow(tester, iPad11Landscape);
    final semantics = tester.ensureSemantics();
    await pumpSweepApp(tester);
    await _tapRow(tester, 'Call the plumber');
    expect(find.byType(TaskDetailPane), findsOneWidget);
    _expectRow(tester, 'Call the plumber', selected: true);
    semantics.dispose();
  }, variant: _iOS);

  for (final size in [androidPhone, androidLandscape, defaultSurface]) {
    testWidgets('at ${sizeName(size)} the sheet marks no row', (tester) async {
      useWindow(tester, size);
      final semantics = tester.ensureSemantics();
      await pumpSweepApp(tester);
      await _tapRow(tester, 'Call the plumber');
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(TaskDetailPane), findsNothing);
      _expectNoRowSelected(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      _expectRow(tester, 'Call the plumber', selected: false);
      semantics.dispose();
    });
  }

  testWidgets('rows of pages over the shell are never selected, the row '
      'beside the pane again once they close', (tester) async {
    useWindow(tester, androidTabletLandscape);
    final semantics = tester.ensureSemantics();
    await pumpSweepApp(tester);
    await _tapRow(tester, 'Call the plumber');

    Finder over(Type page) => find.descendant(
      of: find.byType(page),
      matching: _taskRow('Call the plumber'),
    );

    pushTo(tester, AppRoutes.labelTasks(calls.id));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailPane, skipOffstage: false), findsOneWidget);
    expect(
      tester
          .widget<SelectedTaskHighlight>(_highlight(over(LabelTasksScreen)))
          .selected,
      isFalse,
    );
    expect(
      _semanticsSelected(tester, over(LabelTasksScreen), 'Call the plumber'),
      Tristate.none,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    pushTo(tester, AppRoutes.search);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(SearchPage),
        matching: find.byType(TextField),
      ),
      'plumber',
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SelectedTaskHighlight>(_highlight(over(SearchPage)))
          .selected,
      isFalse,
    );
    expect(
      _semanticsSelected(tester, over(SearchPage), 'Call the plumber'),
      Tristate.none,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(SearchPage), findsNothing);
    _expectRow(tester, 'Call the plumber', selected: true);
    semantics.dispose();
  });

  testWidgets("a queued create's row stays selected once the server names "
      'it, and a tap on it keeps the pane as it is', (tester) async {
    useWindow(tester, androidTabletLandscape);
    final semantics = tester.ensureSemantics();
    final data = sweepData();
    await pumpSweepApp(tester, data: data);
    goTo(tester, AppRoutes.project(workProjectId));
    await tester.pumpAndSettle();
    final localId = await data.tasks.createTask(
      const NewTask(projectId: workProjectId, title: 'Book the venue'),
    );
    await tester.pumpAndSettle();

    await _tapRow(tester, 'Book the venue');
    expect(_paneTaskId(tester), localId);
    _expectRow(tester, 'Book the venue', selected: true);
    final detail = tester.state(_inPane(find.byType(TaskDetailSheet)));

    data.tasks.remapTask(localId, 42);
    await tester.pumpAndSettle();
    expect(_paneTaskId(tester), 42);
    _expectRow(tester, 'Book the venue', selected: true);

    await _tapRow(tester, 'Book the venue');
    expect(
      tester.state(_inPane(find.byType(TaskDetailSheet))),
      same(detail),
      reason: 'the same detail, not a fresh one',
    );
    _expectRow(tester, 'Book the venue', selected: true);
    semantics.dispose();
  });

  testWidgets('when the pane turns into a sheet, no row stays selected', (
    tester,
  ) async {
    useWindow(tester, androidTabletLandscape);
    await pumpSweepApp(tester);
    await _tapRow(tester, 'Call the plumber');
    expect(_paneTaskId(tester), 1);

    useWindow(tester, androidTabletPortrait);
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailPane), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(_paneTaskId(tester), isNull);
    _expectNoRowSelected(tester);
  });

  group('SelectedTaskHighlight', () {
    const child = Key('child');
    final colors = AppTheme.light().colorScheme;

    Future<Rect> pump(
      WidgetTester tester, {
      required bool selected,
      Radius? cardRadius,
      TextDirection direction = TextDirection.ltr,
    }) async {
      await tester.pumpWidget(
        Theme(
          data: AppTheme.light(),
          child: Directionality(
            textDirection: direction,
            child: Material(
              child: Align(
                child: SelectedTaskHighlight(
                  selected: selected,
                  cardRadius: cardRadius,
                  child: const SizedBox(key: child, width: 200, height: 48),
                ),
              ),
            ),
          ),
        ),
      );
      return tester.getRect(find.byKey(child));
    }

    testWidgets('keeps its child in place, selected or not', (tester) async {
      final unselected = await pump(tester, selected: false);
      expect(
        tester.renderObject(find.byType(Material)),
        isNot(paints..rect(color: colors.surfaceContainerHighest)),
      );
      expect(await pump(tester, selected: true), unselected);
    });

    testWidgets("paints a row's bar on its start edge", (tester) async {
      final box = await pump(tester, selected: true);
      expect(
        tester.renderObject(find.byType(Material)),
        paints
          ..rect(rect: box, color: colors.surfaceContainerHighest)
          ..rect(
            rect: Rect.fromLTWH(box.left, box.top, 4, box.height),
            color: colors.primary,
          ),
      );
      await pump(tester, selected: true, direction: TextDirection.rtl);
      expect(
        tester.renderObject(find.byType(Material)),
        paints
          ..rect(rect: box, color: colors.surfaceContainerHighest)
          ..rect(
            rect: Rect.fromLTWH(box.right - 4, box.top, 4, box.height),
            color: colors.primary,
          ),
      );
    });

    testWidgets('outlines a card inside its corners', (tester) async {
      final box = await pump(
        tester,
        selected: true,
        cardRadius: const Radius.circular(12),
      );
      expect(
        tester.renderObject(find.byType(Material)),
        paints
          // The Material's own.
          ..rrect()
          ..rrect(
            rrect: RRect.fromRectAndRadius(box, const Radius.circular(12)),
            color: colors.surfaceContainerHighest,
          )
          ..rrect(
            rrect: RRect.fromRectAndRadius(
              box.deflate(1),
              const Radius.circular(11),
            ),
            color: colors.primary,
            strokeWidth: 2,
            style: PaintingStyle.stroke,
          ),
      );
    });
  });
}
