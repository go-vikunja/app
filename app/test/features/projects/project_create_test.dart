import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/new_project_sheet.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(id: 1, title: 'Work', position: 1),
      sampleProject(id: 3, title: 'Reports', parent: 1),
      sampleProject(id: 2, title: 'Home', position: 2),
      sampleProject(id: 5, title: 'Old', archived: true),
    ];
  });

  Future<void> pumpProjects(WidgetTester tester) async {
    await pumpSignedInApp(tester, sync: data, now: now);
    await openTab(tester, en.tabProjects);
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byTooltip(en.projectNew));
    await tester.pumpAndSettle();
    expect(find.byType(NewProjectSheet), findsOneWidget);
  }

  Finder titleField() => find.descendant(
    of: find.byType(NewProjectSheet),
    matching: find.byType(TextField),
  );

  TextButton createButton(WidgetTester tester) => tester.widget<TextButton>(
    find.widgetWithText(TextButton, en.projectCreate),
  );

  testWidgets('New project in the app bar creates one with its title, parent '
      'and colour, then opens it', (tester) async {
    await pumpProjects(tester);
    await openSheet(tester);
    expect(createButton(tester).onPressed, isNull);
    expect(find.text(en.projectParentTopLevel), findsOneWidget);

    await tester.enterText(titleField(), '  Launch  ');
    await tester.tap(find.text(en.projectParentLabel));
    await tester.pumpAndSettle();
    final picker = find.ancestor(
      of: find.text(en.projectParentTopLevel).last,
      matching: find.byType(ListView),
    );
    expect(
      find.descendant(of: picker, matching: find.text('Reports')),
      findsOneWidget,
    );
    expect(find.text('Old'), findsNothing);
    await tester.tap(find.text('Work').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.bySemanticsLabel(en.taskEditColourSemantics('#0072b2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.projectCreate));
    await tester.pumpAndSettle();

    expect(data.projects.creates, [
      const NewProject(title: 'Launch', parentProjectId: 1, hexColor: '0072b2'),
    ]);
    expect(find.byType(NewProjectSheet), findsNothing);
    expect(find.byType(ProjectTasksScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Launch'), findsOneWidget);
    expect(find.text(en.projectCreated), findsOneWidget);
  });

  testWidgets('a title of only spaces cannot be created', (tester) async {
    await pumpProjects(tester);
    await openSheet(tester);

    await tester.enterText(titleField(), '   ');
    await tester.pump();

    expect(find.text(en.projectTitleRequired), findsOneWidget);
    expect(createButton(tester).onPressed, isNull);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(data.projects.creates, isEmpty);
  });

  testWidgets('while it is created the sheet shows progress and sends '
      'once', (tester) async {
    final answer = Completer<void>();
    data.projects.beforeCall = (_) => answer.future;
    await pumpProjects(tester);
    await openSheet(tester);

    await tester.enterText(titleField(), 'Launch');
    await tester.pump();
    await tester.tap(find.text(en.projectCreate));
    await tester.pump();

    expect(find.text(en.projectCreating), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(data.projects.calls, ['createProject Launch']);

    answer.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ProjectTasksScreen), findsOneWidget);
  });

  testWidgets('dragged shut while it is created, the sheet still opens the '
      'new project', (tester) async {
    final answer = Completer<void>();
    data.projects.beforeCall = (_) => answer.future;
    await pumpProjects(tester);
    await openSheet(tester);

    await tester.enterText(titleField(), 'Launch');
    await tester.pump();
    await tester.tap(find.text(en.projectCreate));
    await tester.pump();
    await tester.fling(
      find.text(en.projectNew).last,
      const Offset(0, 500),
      2000,
    );
    await tester.pumpAndSettle();
    expect(find.byType(NewProjectSheet), findsNothing);

    answer.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ProjectTasksScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Launch'), findsOneWidget);
    expect(find.text(en.projectCreated), findsOneWidget);
  });

  testWidgets('the title takes at most 250 code points, as the server counts '
      'them', (tester) async {
    await pumpProjects(tester);
    await openSheet(tester);

    // 250 characters on screen, 251 code points.
    await tester.enterText(titleField(), '${'a' * 249}👍🏽');
    await tester.pump();

    final text = tester.widget<TextField>(titleField()).controller!.text;
    expect(text.runes, hasLength(250));
    expect(text, startsWith('a' * 249));
  });

  testWidgets('a refusal stays in the sheet with the reason', (tester) async {
    data.projects.failures['createProject'] = const DomainError(
      412,
      code: 3008,
    );
    await pumpProjects(tester);
    await openSheet(tester);

    await tester.enterText(titleField(), 'Launch');
    await tester.pump();
    await tester.tap(find.text(en.projectCreate));
    await tester.pumpAndSettle();

    expect(find.byType(NewProjectSheet), findsOneWidget);
    expect(find.text(en.projectParentArchived), findsOneWidget);
    expect(find.byType(ProjectTasksScreen), findsNothing);

    data.projects.failures['createProject'] = const NetworkFailure(
      NetworkProblem.unreachable,
    );
    await tester.tap(find.text(en.projectCreate));
    await tester.pumpAndSettle();
    expect(find.text(en.projectChangeNeedsConnection), findsOneWidget);
    expect(find.text(en.projectParentArchived), findsNothing);
  });

  testWidgets('without projects the empty state offers a new one', (
    tester,
  ) async {
    data.projects.all = [];
    await pumpProjects(tester);

    expect(find.text(en.projectsEmptyBody), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, en.projectNew));
    await tester.pumpAndSettle();
    expect(find.byType(NewProjectSheet), findsOneWidget);
    expect(find.text(en.projectParentTopLevel), findsOneWidget);
  });
}
