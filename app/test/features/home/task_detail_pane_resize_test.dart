import 'dart:ui'
    show DisplayFeature, DisplayFeatureState, DisplayFeatureType, Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_list_body.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comment_composer.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_pane.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../a11y/sweep_data.dart';
import '../../helpers/large_screens.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/task_detail_panes.dart';
import '../teams/organise_harness.dart' show alice;

final _android = TargetPlatformVariant.only(TargetPlatform.android);

final String _longDescription = [
  for (var line = 1; line <= 60; line++) '<p>Line $line of the plan.</p>',
].join();

Finder _composerIn(Finder detail) => find.descendant(
  of: detail,
  matching: find.descendant(
    of: find.byType(CommentComposer),
    matching: find.byType(TextField),
  ),
);

Task _task(int id) => sweepData().tasks.all.firstWhere((task) => task.id == id);

/// The tabs' area beside the pane.
Rect _listArea(WidgetTester tester) =>
    tester.getRect(find.byType(TaskDetailPaneScope));

ScrollPosition _paneList(WidgetTester tester) => tester
    .state<ScrollableState>(inPane(find.byType(Scrollable)).first)
    .position;

ScrollPosition _projectList(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(ProjectListBody),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

void _seedComments(SyncFakes data) => data.details
  ..me = alice
  ..detailsByTask[1] = const TaskDetails(
    commentCount: 1,
    maxPermission: Permission.write,
  )
  ..commentsByTask[1] = [sampleComment(id: 1)];

DisplayFeature _fold(Rect bounds, {DisplayFeatureState? state}) =>
    DisplayFeature(
      bounds: bounds,
      type: DisplayFeatureType.fold,
      state: state ?? DisplayFeatureState.postureHalfOpened,
    );

void _useFeatures(WidgetTester tester, List<DisplayFeature> features) {
  tester.view.displayFeatures = features;
  addTearDown(tester.view.resetDisplayFeatures);
}

void main() {
  group('losing the room for the pane', () {
    for (final (from, to, variant) in [
      (androidTabletLandscape, androidTabletPortrait, _android),
      (iPad11Landscape, iPad11Portrait, iOSOnly),
    ]) {
      testWidgets('${sizeName(from)} → ${sizeName(to)} opens the same task '
          'as a sheet, with the reply and the text typed just before', (
        tester,
      ) async {
        useWindow(tester, from);
        final semantics = tester.ensureSemantics();
        final data = sweepData();
        _seedComments(data);
        await pumpSweepApp(tester, data: data);
        await tapTaskRow(tester, 1);

        final show = inPane(find.text(en.taskDetailShowComments));
        await tester.scrollUntilVisible(
          show,
          200,
          scrollable: inPane(find.byType(Scrollable)).first,
        );
        await tester.tap(show);
        await tester.pumpAndSettle();
        final menu = inPane(find.byTooltip(en.commentOptions('Anna')));
        await tester.ensureVisible(menu);
        await tester.pumpAndSettle();
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.text(en.commentReply));
        await tester.pumpAndSettle();
        expect(inPane(find.text(en.commentReplyingTo('Anna'))), findsOneWidget);
        await tester.enterText(
          _composerIn(find.byType(TaskDetailPane)),
          'Friday works',
        );
        await tester.pump(const Duration(milliseconds: 100));

        useWindow(tester, to);
        await tester.pumpAndSettle();
        expectSheet(tester, taskId: 1);
        final sheet = find.byType(TaskDetailSheet);
        expect(
          tester.widget<TextField>(_composerIn(sheet)).controller!.text,
          'Friday works',
        );
        expect(
          find.descendant(
            of: sheet,
            matching: find.text(en.commentReplyingTo('Anna')),
          ),
          findsOneWidget,
        );
        expect(paneTaskId(tester), isNull);
        expect([
          for (final state in selectedStatesOf(tester, const [
            'Call the plumber',
          ]))
            state.selected,
        ], everyElement(Tristate.none));

        useWindow(tester, from);
        await tester.pumpAndSettle();
        expectSheet(tester, taskId: 1);
        semantics.dispose();
      }, variant: variant);
    }
  });

  group('a resize that keeps the room keeps the pane as it was', () {
    for (final (from, to, variant) in [
      (iPad13Landscape, iPad13Portrait, iOSOnly),
      (androidTabletLandscape, const Size(1000, 800), _android),
    ]) {
      testWidgets('${sizeName(from)} → ${sizeName(to)}', (tester) async {
        useWindow(tester, from);
        final data = sweepData();
        data.tasks.all = [
          for (final task in data.tasks.all)
            if (task.id == 4)
              task.copyWith(description: _longDescription)
            else
              task,
          for (var id = 100; id < 130; id++)
            sampleTask(id: id, title: 'Filler $id'),
        ];
        await pumpSweepApp(tester, data: data);
        goTo(tester, AppRoutes.project(workProjectId));
        await tester.pumpAndSettle();
        await tapOutsidePane(tester, taskRowOf(120));
        expect(_projectList(tester).pixels, greaterThan(0));
        tester
            .widget<TaskDetailSheet>(paneDetail)
            .pane!
            .openOther(_task(4).copyWith(description: _longDescription));
        await tester.pumpAndSettle();
        final pane = _paneList(tester);
        pane.jumpTo(pane.maxScrollExtent / 2);
        await tester.pumpAndSettle();
        final paneOffset = _paneList(tester).pixels;
        expect(paneOffset, greaterThan(0));
        final listOffset = _projectList(tester).pixels;
        final detail = tester.state(paneDetail);

        useWindow(tester, to);
        await tester.pumpAndSettle();
        expectPane(tester, taskId: 4);
        expect(tester.state(paneDetail), same(detail));
        expect(inPane(find.byType(BackButtonIcon)), findsOneWidget);
        expect(_paneList(tester).pixels, paneOffset);
        expect(_projectList(tester).pixels, listOffset);
        expect(
          tester.getRect(find.byType(TaskDetailPane)).width,
          moreOrLessEquals(expectedPaneWidth(tester, to)),
        );
      }, variant: variant);
    }
  });

  testWidgets('with the keyboard up the composer stays above it, and the '
      'list beside keeps its place', (tester) async {
    useWindow(tester, androidTabletLandscape);
    await pumpSweepApp(tester);
    await tapTaskRow(tester, 1);
    final list = _listArea(tester);

    tester.view.viewInsets = FakeViewPadding(
      bottom: 350 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expectPane(tester, taskId: 1);
    final field = tester.getRect(_composerIn(find.byType(TaskDetailPane)));
    expect(field.bottom, lessThanOrEqualTo(800 - 350));
    expect(field.bottom, greaterThanOrEqualTo(800 - 350 - 80));
    final beside = _listArea(tester);
    expect(beside.left, list.left);
    expect(beside.right, list.right);
    expect(beside.top, list.top);
  });

  group('folds and hinges', () {
    testWidgets('a half-opened vertical fold splits the list and the pane '
        'on it', (tester) async {
      useWindow(tester, androidTabletLandscape);
      _useFeatures(tester, [_fold(const Rect.fromLTWH(640, 0, 0, 800))]);
      await pumpSweepApp(tester);
      await tapTaskRow(tester, 1);
      final list = _listArea(tester);
      final pane = tester.getRect(find.byType(TaskDetailPane));
      expect(list.left, railRight(tester));
      expect(list.right, 640);
      expect(list.width, 640 - railRight(tester));
      expect(pane.left, 640);
      expect(pane.width, 640);
      expect(find.byType(VerticalDivider), findsNothing);
    });

    testWidgets('a hinge lies between the list and the pane', (tester) async {
      useWindow(tester, androidTabletLandscape);
      _useFeatures(tester, [
        const DisplayFeature(
          bounds: Rect.fromLTWH(630, 0, 20, 800),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureFlat,
        ),
      ]);
      await pumpSweepApp(tester);
      await tapTaskRow(tester, 1);
      expect(_listArea(tester).right, 630);
      expect(tester.getRect(find.byType(TaskDetailPane)).left, 650);
      expect(tester.getRect(find.byType(TaskDetailPane)).right, 1280);
      expect(find.byType(VerticalDivider), findsNothing);
    });

    testWidgets('a flat fold of no width leaves the normal split', (
      tester,
    ) async {
      useWindow(tester, androidTabletLandscape);
      _useFeatures(tester, [
        _fold(
          const Rect.fromLTWH(640, 0, 0, 800),
          state: DisplayFeatureState.postureFlat,
        ),
      ]);
      await pumpSweepApp(tester);
      await tapTaskRow(tester, 1);
      final pane = tester.getRect(find.byType(TaskDetailPane));
      expect(
        pane.width,
        moreOrLessEquals(expectedPaneWidth(tester, androidTabletLandscape)),
      );
      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(_listArea(tester).right, pane.left - 1);
    });

    testWidgets('a half-opened horizontal fold opens sheets', (tester) async {
      useWindow(tester, androidTabletLandscape);
      _useFeatures(tester, [_fold(const Rect.fromLTWH(0, 400, 1280, 0))]);
      await pumpSweepApp(tester);
      await tapTaskRow(tester, 1);
      expectSheet(tester, taskId: 1);
    });

    testWidgets('841×701 with a fold at 420 keeps the normal split beside '
        "the test's wider rail", (tester) async {
      useWindow(tester, androidFoldable);
      _useFeatures(tester, [_fold(const Rect.fromLTWH(420, 0, 0, 701))]);
      await pumpSweepApp(tester);
      await tapTaskRow(tester, 1);
      // 128 dp of rail leave 292 dp left of the fold, under the 320 a side
      // needs; a device's 80 dp rail leaves 340.
      final pane = tester.getRect(find.byType(TaskDetailPane));
      expect(pane.width, 360);
      expect(pane.right, androidFoldable.width);
      expect(find.byType(VerticalDivider), findsOneWidget);
    });
  });
}
