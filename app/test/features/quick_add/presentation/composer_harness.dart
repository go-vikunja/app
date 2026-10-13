import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/platform/app_shortcuts.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/quick_add/application/local_quick_add_service.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_plan.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_service_provider.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_text_controller.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';

import '../../../helpers/fake_quick_add_service.dart';
import '../../../helpers/label_user_fakes.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/sample_data.dart';
import '../../../helpers/sync_fakes.dart';

/// A Saturday at noon.
final DateTime composerNow = DateTime(2026, 10, 10, 12);

final Project work = sampleProject(
  id: 1,
  title: 'Work',
  position: 1,
  identifier: 'WRK',
);
final Project inbox = sampleProject(id: 2, title: 'Inbox', position: 2);
final Project garageSale = sampleProject(
  id: 3,
  title: 'Garage Sale',
  position: 3,
);
final Project gardening = sampleProject(
  id: 4,
  title: 'Gardening',
  position: 4,
  archived: true,
);
final Label urgent = sampleLabel(id: 10, title: 'urgent', hexColor: 'ff006e');
final Label roadTrip = sampleLabel(
  id: 11,
  title: 'Road trip',
  hexColor: '3a86ff',
);
const sam = User(id: 5, username: 'sam', name: 'Sam Example');
const alex = User(id: 6, username: 'alex', name: 'Alex Doe');

/// Records what the app registers and lets a test open it with a shortcut;
/// [launchAction] is reported as soon as the app initializes, like a
/// shortcut that launched it.
final class FakeAppShortcuts implements AppShortcuts {
  new({this.launchAction});

  final String? launchAction;
  final List<String> titles = [];
  late void Function(String type) _onAction;

  @override
  Future<void> initialize(void Function(String type) onAction) async {
    _onAction = onAction;
    if (launchAction case final type?) onAction(type);
  }

  @override
  Future<void> setNewTaskShortcut(String localizedTitle) async =>
      titles.add(localizedTitle);

  void trigger(String type) => _onAction(type);
}

/// The signed-in app with the composer's collaborators faked. Plans come
/// from the real quick add over the sample projects, labels and people as
/// they are when a line is planned; only submits are faked.
final class ComposerHarness {
  new() {
    data.projects.all = [work, inbox, garageSale, gardening];
  }

  final data = SyncFakes(now: composerNow);
  final labels = FakeLabelRepository(labels: [urgent, roadTrip]);
  final users = FakeUserRepository(
    known: [sam],
    projectUsers: {
      1: [sam, alex],
      2: [sam, alex],
    },
  );
  FakeAppShortcuts shortcuts = FakeAppShortcuts();

  /// Whom plans resolve `@names` to, like the service's known people.
  List<User> knownUsers = [sam];
  UserSettings get settings => data.shared.settings;
  set settings(UserSettings settings) => data.shared.settings = settings;
  late final service = FakeQuickAddService(planner: _plan);

  QuickAddPlan _plan(
    String line, {
    int? fallbackProjectId,
    DateTime? fallbackDueDate,
  }) =>
      LocalQuickAddService(
        snapshot: QuickAddSnapshot(
          projects: data.projects.all,
          labels: labels.labels,
          knownUsers: knownUsers,
          settings: settings,
        ),
        tasks: data.tasks,
        labels: labels,
        users: users,
        now: () => composerNow,
      ).plan(
        line,
        fallbackProjectId: fallbackProjectId,
        fallbackDueDate: fallbackDueDate,
      );

  List<Override> get overrides => [
    quickAddServiceProvider.overrideWithValue(service),
    labelRepositoryProvider.overrideWithValue(labels),
    userRepositoryProvider.overrideWithValue(users),
    appShortcutsProvider.overrideWithValue(shortcuts),
  ];

  Future<void> pumpApp(WidgetTester tester) async {
    usePhoneSurface(tester);
    await pumpSignedInApp(
      tester,
      sync: data,
      now: composerNow,
      overrides: overrides,
    );
  }

  /// Opens the sheet from the overview's FAB, or from project [projectId]'s.
  Future<void> open(WidgetTester tester, {int? projectId}) async {
    await pumpApp(tester);
    if (projectId != null) {
      containerOf(tester)
          .read(appRouterProvider)
          .go(AppRoutes.project(projectId));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(NewTaskSheet), findsOneWidget);
  }
}

Finder composerField() => find.descendant(
  of: find.byType(NewTaskSheet),
  matching: find.byType(TextField),
);

MagicTextEditingController composerController(WidgetTester tester) =>
    tester.widget<TextField>(composerField()).controller!
        as MagicTextEditingController;

Future<void> typeLine(WidgetTester tester, String text) async {
  await tester.enterText(composerField(), text);
  await tester.pump();
}

/// Puts [text] in the field with the caret at [caret] (the end without).
Future<void> setComposerText(
  WidgetTester tester,
  String text, {
  int? caret,
}) async {
  composerController(tester).value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: caret ?? text.length),
  );
  await tester.pump();
}

String composerText(WidgetTester tester) => composerController(tester).text;
