import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_row.dart';
import 'package:vikunja_mobile/features/projects/presentation/reorder_slot.dart';

import '../../helpers/announcer_region.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;

  List<Project> tree() => [
    sampleProject(id: 1, title: 'Work', position: 200),
    sampleProject(id: 2, title: 'Home', position: 100),
    sampleProject(id: 3, title: 'Reports', parent: 1, position: 20),
    sampleProject(id: 4, title: 'Admin', parent: 1, position: 10),
    sampleProject(id: 5, title: 'Q1', parent: 3, position: 5),
    sampleProject(id: 6, title: 'Old', position: 300, archived: true),
    sampleProject(id: 7, title: 'Garden', position: 400),
  ];

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = tree();
  });

  Future<void> pumpProjects(WidgetTester tester, {String? tab}) async {
    usePhoneSurface(tester, logicalSize: const Size(400, 1200));
    await pumpSignedInApp(tester, sync: data, now: now);
    await openTab(tester, tab ?? en.tabProjects);
  }

  List<(String, int)> treeRows(WidgetTester tester) => [
    for (final row in tester.widgetList<ProjectRow>(find.byType(ProjectRow)))
      (row.project.title, row.depth),
  ];

  Finder rowOf(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(ProjectRow));

  Offset nearTop(WidgetTester tester, String title) {
    final rect = tester.getRect(rowOf(title));
    return Offset(rect.center.dx, rect.top + rect.height * 0.1);
  }

  Offset nearBottom(WidgetTester tester, String title) {
    final rect = tester.getRect(rowOf(title));
    return Offset(rect.center.dx, rect.bottom - rect.height * 0.1);
  }

  /// Long-presses [title]'s row and moves it to [to] in steps, then lets
  /// go. Positions are taken before: the held row also hangs under the
  /// finger.
  Future<void> dragProject(WidgetTester tester, String title, Offset to) async {
    final from = tester.getCenter(rowOf(title));
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    for (var step = 1; step <= 6; step++) {
      await gesture.moveTo(Offset.lerp(from, to, step / 6)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  /// Measured inside the translation that lifts it.
  Rect liftedRect(WidgetTester tester) => tester.getRect(
    find
        .descendant(
          of: find.byType(LiftedRows),
          matching: find.byType(Material),
        )
        .first,
  );

  ReorderSlot<int> slotOf(WidgetTester tester, int projectId) => tester
      .widget<ReorderSlot<int>>(find.byKey(ValueKey(('tree', projectId))));

  List<String> actionsOf(WidgetTester tester, String title) => [
    for (final id
        in tester
                .getSemantics(find.text(title))
                .getSemanticsData()
                .customSemanticsActionIds ??
            const <int>[])
      CustomSemanticsAction.getAction(id)!.label!,
  ];

  Future<void> performAction(
    WidgetTester tester,
    String title,
    String label,
  ) async {
    final node = tester.getSemantics(find.text(title));
    node.owner!.performAction(
      node.id,
      SemanticsAction.customAction,
      CustomSemanticsAction.getIdentifier(CustomSemanticsAction(label: label)),
    );
    await tester.pumpAndSettle();
  }

  List<Object?> recordHaptics(WidgetTester tester) {
    final calls = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return calls;
  }

  group('dragging', () {
    testWidgets('a project dropped near the top of a sibling goes before '
        'it, with a haptic and an announcement', (tester) async {
      final haptics = recordHaptics(tester);
      await pumpProjects(tester);
      expect(treeRows(tester), [
        ('Home', 0),
        ('Work', 0),
        ('Admin', 1),
        ('Reports', 1),
        ('Q1', 2),
        ('Garden', 0),
      ]);

      await dragProject(tester, 'Garden', nearTop(tester, 'Home'));

      expect(data.projects.moves, [
        (projectId: 7, position: 50.0, parentProjectId: 0),
      ]);
      expect(treeRows(tester).first, ('Garden', 0));
      // The lift's and the move's.
      expect(
        haptics.where((kind) => kind == 'HapticFeedbackType.selectionClick'),
        hasLength(2),
      );
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.movedUp),
      ]);
    });

    testWidgets('dropped onto a project it becomes its last subproject, '
        'which shows', (tester) async {
      data.listPreferences.projectTree = const ProjectTreePreferences(
        collapsed: {1},
      );
      await pumpProjects(tester);
      expect(treeRows(tester), [('Home', 0), ('Work', 0), ('Garden', 0)]);

      await dragProject(tester, 'Home', tester.getCenter(rowOf('Work')));

      expect(data.projects.moves, [
        (projectId: 2, position: 20.0 + 65536, parentProjectId: 1),
      ]);
      expect(data.listPreferences.projectTree.collapsed, isEmpty);
      expect(treeRows(tester), [
        ('Work', 0),
        ('Admin', 1),
        ('Reports', 1),
        ('Q1', 2),
        ('Home', 1),
        ('Garden', 0),
      ]);
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.projectMovedInto('Work')),
      ]);
    });

    testWidgets('below the last row of an open branch it lands on that '
        "row's level, above the next row on the next row's", (tester) async {
      await pumpProjects(tester);

      await dragProject(tester, 'Garden', nearBottom(tester, 'Q1'));
      expect(data.projects.moves.last, (
        projectId: 7,
        position: 5.0 + 65536,
        parentProjectId: 3,
      ));
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.projectMovedInto('Reports')),
      ]);

      data.projects.all = tree();
      await tester.pumpAndSettle();
      await dragProject(tester, 'Admin', nearTop(tester, 'Garden'));
      expect(data.projects.moves.last, (
        projectId: 4,
        position: 300.0,
        parentProjectId: 0,
      ));
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.projectMovedToTopLevel),
      ]);
    });

    testWidgets('below the last row it goes to the end of the top level', (
      tester,
    ) async {
      await pumpProjects(tester);
      final belowAll = tester.getRect(rowOf('Garden')).bottom + 20;

      await dragProject(
        tester,
        'Q1',
        Offset(tester.getCenter(rowOf('Garden')).dx, belowAll),
      );

      expect(data.projects.moves, [
        (projectId: 5, position: 400.0 + 65536, parentProjectId: 0),
      ]);
    });

    testWidgets('while held, the line shows the level a drop lands on, an '
        'outline the project a drop goes into', (tester) async {
      await pumpProjects(tester);
      final afterQ1 = nearBottom(tester, 'Q1');
      final aboveGarden = nearTop(tester, 'Garden');
      final ontoAdmin = tester.getCenter(rowOf('Admin'));
      final gesture = await tester.startGesture(
        tester.getCenter(rowOf('Home')),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await gesture.moveTo(afterQ1);
      await tester.pump();
      expect(
        tester.widget<DropLine>(find.byType(DropLine)).indent,
        ProjectRow.indentOf(2),
      );
      await gesture.moveTo(aboveGarden);
      await tester.pump();
      expect(
        tester.widget<DropLine>(find.byType(DropLine)).indent,
        ProjectRow.indentOf(0),
      );
      await gesture.moveTo(ontoAdmin);
      await tester.pump();
      expect(find.byType(DropLine), findsNothing);
      expect(
        tester
            .widgetList<ReorderSlot<int>>(find.byType(ReorderSlot<int>))
            .where((slot) => slot.dropsInto)
            .map((slot) => slot.id),
        [4],
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the held rows hang above the finger, clear of the drop '
        'line and of the outline of the project a drop goes into', (
      tester,
    ) async {
      await pumpProjects(tester);
      final ontoHome = tester.getCenter(rowOf('Home'));
      final aboveWork = nearTop(tester, 'Work');
      final gesture = await tester.startGesture(
        tester.getCenter(rowOf('Garden')),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await gesture.moveTo(ontoHome);
      await tester.pump();
      expect(slotOf(tester, 2).dropsInto, isTrue);
      expect(liftedRect(tester).bottom, lessThan(ontoHome.dy));
      expect(
        liftedRect(tester).overlaps(tester.getRect(rowOf('Home'))),
        isFalse,
      );

      await gesture.moveTo(aboveWork);
      await tester.pump();
      expect(
        liftedRect(tester).overlaps(tester.getRect(find.byType(DropLine))),
        isFalse,
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a long press on the expand button lifts the project too', (
      tester,
    ) async {
      await pumpProjects(tester);
      final toggle = find.byTooltip(en.projectCollapse('Work'));
      final aboveHome = nearTop(tester, 'Home');

      final gesture = await tester.startGesture(tester.getCenter(toggle));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(LiftedRows), findsOne);
      await gesture.moveTo(aboveHome);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(data.projects.moves.single.projectId, 1);
      expect(data.listPreferences.projectTree.collapsed, isEmpty);
    });

    testWidgets('let go on or right around its own row, a project stays '
        'without a refusal', (tester) async {
      final haptics = recordHaptics(tester);
      await pumpProjects(tester);
      final work = tester.getCenter(rowOf('Work'));
      final workBottom = nearBottom(tester, 'Work');
      final adminTop = nearTop(tester, 'Admin');

      for (final to in [work + const Offset(40, 0), workBottom, adminTop]) {
        final gesture = await tester.startGesture(work);
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveTo(to);
        await tester.pump();
        expect(find.byType(DropLine), findsNothing);
        await gesture.up();
        await tester.pumpAndSettle();
      }

      expect(haptics, everyElement('HapticFeedbackType.selectionClick'));
      expect(data.projects.moves, isEmpty);
    });

    testWidgets('refused with a haptic and without a request: onto its own '
        'subproject, into an archived project, and an archived project '
        'itself', (tester) async {
      final haptics = recordHaptics(tester);
      data.listPreferences.projectTree = const ProjectTreePreferences(
        showArchived: true,
      );
      await pumpProjects(tester);

      await dragProject(tester, 'Work', tester.getCenter(rowOf('Q1')));
      await dragProject(tester, 'Work', nearTop(tester, 'Q1'));
      await dragProject(tester, 'Home', tester.getCenter(rowOf('Old')));
      expect(
        haptics.where((kind) => kind == 'HapticFeedbackType.heavyImpact'),
        hasLength(3),
      );

      haptics.clear();
      final gesture = await tester.startGesture(tester.getCenter(rowOf('Old')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(LiftedRows), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(haptics, ['HapticFeedbackType.heavyImpact']);

      expect(data.projects.moves, isEmpty);
      expect(tester.takeAnnouncements(), isEmpty);
    });

    testWidgets('a place whose position would fall below 0.1 is not offered', (
      tester,
    ) async {
      final haptics = recordHaptics(tester);
      data.projects.all = [
        sampleProject(id: 1, title: 'Tiny', position: 0.15),
        sampleProject(id: 2, title: 'Next', position: 10),
      ];
      await pumpProjects(tester);
      final aboveTiny = nearTop(tester, 'Tiny');
      final gesture = await tester.startGesture(
        tester.getCenter(rowOf('Next')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(aboveTiny);
      await tester.pump();
      expect(find.byType(DropLine), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(data.projects.moves, isEmpty);
      expect(haptics, contains('HapticFeedbackType.heavyImpact'));
    });

    testWidgets('the tree scrolls while a project is held near its end', (
      tester,
    ) async {
      data.projects.all = [
        for (var id = 1; id <= 30; id++)
          sampleProject(id: id, title: 'Project $id', position: id * 100.0),
      ];
      await pumpProjects(tester);
      tester.view.physicalSize = const Size(400, 700) * 3;
      await tester.pumpAndSettle();
      final list = find
          .ancestor(of: rowOf('Project 1'), matching: find.byType(Scrollable))
          .first;
      final position = tester.state<ScrollableState>(list).position;
      expect(position.pixels, 0);

      final from = tester.getCenter(rowOf('Project 2'));
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(Offset(from.dx, tester.getRect(list).bottom - 8));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(position.pixels, greaterThan(0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(data.projects.moves.single.projectId, 2);
    });

    testWidgets('the favourites stay as they are', (tester) async {
      data.projects.all = [
        sampleProject(id: 2, title: 'Home', position: 100, favorite: true),
        sampleProject(id: 7, title: 'Garden', position: 400),
      ];
      await pumpProjects(tester);
      // The section card's slot carries the row's key too.
      final favourite = find.byKey(const ValueKey(('favourite', 2))).last;
      final garden = tester.getCenter(rowOf('Garden'));

      final gesture = await tester.startGesture(tester.getCenter(favourite));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(LiftedRows), findsNothing);
      await gesture.moveTo(garden);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(data.projects.moves, isEmpty);
      expect(
        tester
            .getSemantics(favourite)
            .getSemanticsData()
            .customSemanticsActionIds,
        anyOf(isNull, isEmpty),
      );
    });
  });

  group('while a move is on its way', () {
    // Made in the test's fake async zone, which it must complete in.
    Completer<void> holdServer() {
      final server = Completer<void>();
      data.projects.beforeMove = () => server.future;
      return server;
    }

    testWidgets('the project shows in its new place, faded; another lift is '
        'refused with a haptic, another action announced', (tester) async {
      final haptics = recordHaptics(tester);
      final server = holdServer();
      await pumpProjects(tester);

      await dragProject(tester, 'Garden', nearTop(tester, 'Home'));
      expect(treeRows(tester).first, ('Garden', 0));
      expect(slotOf(tester, 7).held, isTrue);
      expect(tester.takeAnnouncements(), isEmpty);

      haptics.clear();
      final gesture = await tester.startGesture(
        tester.getCenter(rowOf('Home')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(LiftedRows), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(haptics, ['HapticFeedbackType.heavyImpact']);

      await performAction(tester, 'Home', en.moveDown);
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.projectMoveWait),
      ]);
      expect(data.projects.moves, hasLength(1));

      server.complete();
      await tester.pumpAndSettle();
      expect(treeRows(tester).first, ('Garden', 0));
      expect(slotOf(tester, 7).held, isFalse);
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.movedUp),
      ]);
    });

    testWidgets('a refusal puts it back', (tester) async {
      final server = holdServer();
      await pumpProjects(tester);
      final rowsBefore = treeRows(tester);
      data.projects.moveFailure = const DomainError(412, code: 3008);

      await dragProject(tester, 'Garden', nearTop(tester, 'Home'));
      expect(treeRows(tester).first, ('Garden', 0));

      server.complete();
      await tester.pumpAndSettle();
      expect(treeRows(tester), rowsBefore);
      expect(slotOf(tester, 7).held, isFalse);
      expect(find.text(en.projectMoveArchived), findsOne);
    });
  });

  group('screen readers', () {
    testWidgets('move a project among its siblings, out of its parent and '
        'into the sibling above, announced', (tester) async {
      await pumpProjects(tester);

      expect(actionsOf(tester, 'Home'), unorderedEquals([en.moveDown]));
      expect(
        actionsOf(tester, 'Work'),
        unorderedEquals([en.moveUp, en.moveDown, en.projectMoveInto('Home')]),
      );
      expect(
        actionsOf(tester, 'Admin'),
        unorderedEquals([en.moveDown, en.projectMoveOut('Work')]),
      );
      expect(
        actionsOf(tester, 'Reports'),
        unorderedEquals([
          en.moveUp,
          en.projectMoveOut('Work'),
          en.projectMoveInto('Admin'),
        ]),
      );

      await performAction(tester, 'Reports', en.projectMoveOut('Work'));
      expect(data.projects.moves.last, (
        projectId: 3,
        position: 300.0,
        parentProjectId: 0,
      ));
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.projectMovedOut('Work')),
      ]);

      await performAction(tester, 'Home', en.moveDown);
      expect(data.projects.moves.last, (
        projectId: 2,
        position: 250.0,
        parentProjectId: 0,
      ));
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.movedDown),
      ]);
    });

    testWidgets('without platform announcements, as on Android, a move is '
        'said by the live region', (tester) async {
      useLiveRegionAnnouncements(tester);
      await pumpProjects(tester);

      await performAction(tester, 'Reports', en.projectMoveOut('Work'));

      expect(data.projects.moves.last.projectId, 3);
      expect(tester.takeAnnouncements(), isEmpty);
      final region = announcerRegion(tester)!;
      expect(region.label, en.projectMovedOut('Work'));
      expect(region.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    });

    testWidgets('moving into a collapsed project shows its subprojects', (
      tester,
    ) async {
      data.listPreferences.projectTree = const ProjectTreePreferences(
        collapsed: {1},
      );
      await pumpProjects(tester);

      await performAction(tester, 'Garden', en.projectMoveInto('Work'));

      expect(data.projects.moves, [
        (projectId: 7, position: 20.0 + 65536, parentProjectId: 1),
      ]);
      expect(data.listPreferences.projectTree.collapsed, isEmpty);
      expect(treeRows(tester).last, ('Garden', 1));
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.projectMovedInto('Work')),
      ]);
    });

    testWidgets('an archived project offers none', (tester) async {
      data.listPreferences.projectTree = const ProjectTreePreferences(
        showArchived: true,
      );
      await pumpProjects(tester);

      expect(actionsOf(tester, 'Old'), isEmpty);
      expect(actionsOf(tester, 'Garden'), unorderedEquals([en.moveUp]));
    });

    testWidgets('are in German', (tester) async {
      useLocale(tester, const Locale('de'));
      await pumpProjects(tester, tab: de.tabProjects);

      expect(
        actionsOf(tester, 'Reports'),
        unorderedEquals([
          de.moveUp,
          de.projectMoveOut('Work'),
          de.projectMoveInto('Admin'),
        ]),
      );
      await performAction(tester, 'Reports', de.projectMoveInto('Admin'));
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(de.projectMovedInto('Admin')),
      ]);
    });
  });

  group('a refused move changes nothing and says why', () {
    Future<String> failureOf(
      WidgetTester tester,
      Exception failure, {
      required String title,
      required String action,
    }) async {
      final haptics = recordHaptics(tester);
      data.projects.moveFailure = failure;
      await performAction(tester, title, action);
      expect(haptics, contains('HapticFeedbackType.heavyImpact'));
      expect(tester.takeAnnouncements(), isEmpty);
      final text = tester
          .widget<Text>(
            find.descendant(
              of: find.byType(SnackBar),
              matching: find.byType(Text),
            ),
          )
          .data!;
      ScaffoldMessenger.of(tester.element(find.byType(SnackBar)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      return text;
    }

    testWidgets('in the words of each failure', (tester) async {
      await pumpProjects(tester);
      final rowsBefore = treeRows(tester);
      final out = en.projectMoveOut('Work');

      expect(
        await failureOf(
          tester,
          const Forbidden(code: 1),
          title: 'Reports',
          action: out,
        ),
        en.projectMoveAdminOnly,
      );
      expect(
        await failureOf(
          tester,
          const Forbidden(code: 0),
          title: 'Reports',
          action: en.moveUp,
        ),
        en.projectMoveForbidden,
      );
      expect(
        await failureOf(
          tester,
          const DomainError(412, code: 3008),
          title: 'Reports',
          action: out,
        ),
        en.projectMoveArchived,
      );
      for (final code in [3009, 3010, 3011]) {
        expect(
          await failureOf(
            tester,
            DomainError(412, code: code),
            title: 'Reports',
            action: out,
          ),
          en.projectMoveNotPossible,
        );
      }
      expect(
        await failureOf(
          tester,
          const NotFound(code: 3001),
          title: 'Reports',
          action: out,
        ),
        en.projectMoveGone,
      );
      expect(
        await failureOf(
          tester,
          const NetworkFailure(NetworkProblem.unreachable),
          title: 'Reports',
          action: out,
        ),
        en.projectMoveNeedsConnection,
      );
      expect(
        await failureOf(
          tester,
          const NetworkFailure(NetworkProblem.timeout),
          title: 'Reports',
          action: out,
        ),
        en.projectMoveUnconfirmed,
      );
      expect(
        await failureOf(
          tester,
          const ServerFailure(500),
          title: 'Reports',
          action: out,
        ),
        en.projectMoveFailed,
      );
      expect(treeRows(tester), rowsBefore);
    });

    testWidgets('in German', (tester) async {
      useLocale(tester, const Locale('de'));
      await pumpProjects(tester, tab: de.tabProjects);

      expect(
        await failureOf(
          tester,
          const Forbidden(code: 1),
          title: 'Admin',
          action: de.projectMoveOut('Work'),
        ),
        de.projectMoveAdminOnly,
      );
    });
  });
}
