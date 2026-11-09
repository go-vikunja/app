import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/task_opener.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/trash/presentation/trash_feedback.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fake_sync_client.dart';
import '../../helpers/guest_app.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/test_database.dart';

const String _scheme = oauthCallbackScheme;

void main() {
  late SyncFakes data;

  NotFound inTrash({bool canRestore = true}) => NotFound(
    code: 4040,
    trash: TrashDetails(id: 7, canRestore: canRestore, projectId: 1),
  );

  setUp(() {
    data = SyncFakes();
    data.projects.all = [sampleProject(id: 1, title: 'Work')];
    data.tasks.all = [];
    data.tasks.restorable[7] = sampleTask(id: 7, title: 'Water the plants');
  });

  final sheet = find.byType(TaskDetailSheet);

  Future<void> open(WidgetTester tester) async {
    await tester.binding.handlePushRoute('$_scheme://task/7');
    await tester.pumpAndSettle();
  }

  Future<void> pumpUser(WidgetTester tester) =>
      pumpSignedInApp(tester, sync: data, connection: fullServer280());

  testWidgets('a task in the bin says so and offers Restore, which brings '
      'it back and opens it', (tester) async {
    data.resolver.failures[const TaskById(7)] = inTrash();
    await pumpUser(tester);

    await open(tester);

    expect(sheet, findsNothing);
    expect(find.text(en.taskOpenInTrash), findsOneWidget);
    expect(find.text(en.taskOpenNotFound), findsNothing);
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.duration, deletedSnackBarDuration);
    expect(snackBar.persist, isFalse);

    await tester.tap(find.text(en.trashRestore));
    await tester.pumpAndSettle();

    expect(data.tasks.writes, ['restore 7']);
    expect(
      find.descendant(of: sheet, matching: find.text('Water the plants')),
      findsOneWidget,
    );
    expect(find.text(en.taskOpenInTrash), findsNothing);
  });

  testWidgets('under a screen reader the Restore waits for the user', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          accessibleNavigation: true,
          supportsAnnounce: true,
        );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    data.resolver.failures[const TaskById(7)] = inTrash();
    await pumpUser(tester);

    await open(tester);
    await tester.pump(deletedSnackBarDuration * 3);
    await tester.pumpAndSettle();

    expect(find.text(en.trashRestore), findsOneWidget);
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).persist, isTrue);
  });

  testWidgets('a Restore that fails says why and opens nothing', (
    tester,
  ) async {
    data.resolver.failures[const TaskById(7)] = inTrash();
    data.tasks.restoreFailure = const DomainError(412, code: 3008);
    await pumpUser(tester);
    await open(tester);

    await tester.tap(find.text(en.trashRestore));
    await tester.pumpAndSettle();

    expect(data.tasks.writes, ['restore 7']);
    expect(find.text(en.trashRestoreArchived), findsOneWidget);
    expect(sheet, findsNothing);
  });

  for (final (name, failure) in [
    ('that the user may not restore', inTrash(canRestore: false)),
    ('without details', const NotFound(code: 4040)),
  ]) {
    testWidgets('a task in the bin $name only says so', (tester) async {
      data.resolver.failures[const TaskById(7)] = failure;
      await pumpUser(tester);

      await open(tester);

      expect(find.text(en.taskOpenInTrash), findsOneWidget);
      expect(find.text(en.trashRestore), findsNothing);
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).action, isNull);
    });
  }

  testWidgets('a link-share guest is not offered Restore, as on the web', (
    tester,
  ) async {
    data.projects.all = [];
    data.resolver.failures[const TaskById(7)] = inTrash();
    await pumpGuestApp(
      tester,
      auth: AuthFakes(),
      data: data,
      permission: Permission.write,
      connection: fullServer280(),
    );

    await open(tester);

    expect(find.text(en.taskOpenInTrash), findsOneWidget);
    expect(find.text(en.trashRestore), findsNothing);
    expect(data.tasks.writes, isEmpty);
  });

  testWidgets('a 2.8.0 server whose /api/v2 cannot be reached has no bin to '
      'restore from, so no Restore', (tester) async {
    final full = fullServer280();
    const v1Only = {ApiVersion.v1};
    data.resolver.failures[const TaskById(7)] = inTrash();
    await pumpSignedInApp(
      tester,
      sync: data,
      connection: ServerConnection(
        rootUri: full.rootUri,
        apiVersions: v1Only,
        info: full.info,
        capabilities: ServerCapabilities.derive(
          info: full.info,
          apiVersions: v1Only,
        ),
      ),
    );

    await open(tester);

    expect(find.text(en.taskOpenInTrash), findsOneWidget);
    expect(find.text(en.trashRestore), findsNothing);
    expect(data.tasks.writes, isEmpty);
  });

  testWidgets('a task whose project is in the bin says so, without Restore', (
    tester,
  ) async {
    data.resolver.failures[const TaskById(7)] = const NotFound(
      code: 3018,
      trash: TrashDetails(id: 1, canRestore: true),
    );
    await pumpUser(tester);

    await open(tester);

    expect(find.text(en.taskOpenProjectInTrash), findsOneWidget);
    expect(find.text(en.trashRestore), findsNothing);
    expect(sheet, findsNothing);
  });

  testWidgets('a task gone for good is still not found', (tester) async {
    await pumpUser(tester);

    await open(tester);

    expect(find.text(en.taskOpenNotFound), findsOneWidget);
    expect(find.text(en.trashRestore), findsNothing);
  });

  testWidgets('is in German', (tester) async {
    useLocale(tester, const Locale('de'));
    data.resolver.failures[const TaskById(7)] = inTrash();
    await pumpUser(tester);

    await open(tester);

    expect(find.text(de.taskOpenInTrash), findsOneWidget);
    expect(find.text(de.trashRestore), findsOneWidget);
  });

  group('accountServerTaskRead', () {
    late AppDatabase db;
    late FakeSyncClient server;
    late ServerTaskRead read;

    setUp(() async {
      db = testDatabase();
      addTearDown(db.close);
      server = FakeSyncClient();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWith((ref, _) => db),
          readClientProvider.overrideWith((ref, _) => server),
        ],
      );
      addTearDown(container.dispose);
      read = container
          .listen(accountServerTaskReadProvider('alice'), (_, _) {})
          .read();
      await db.projectsDao.upsertAll([sampleProject(id: 1, title: 'Work')]);
      await db.tasksDao.upsertAll([sampleTask(id: 7, title: 'Stale')]);
    });

    test('reads the task although this device has it, and stores what the '
        'server answers', () async {
      server.allTasks = [sampleTask(id: 7, title: 'Water the plants')];

      final task = await read(7);

      expect(server.requests, ['task 7']);
      expect(task.title, 'Water the plants');
      expect((await db.tasksDao.find(7))?.title, 'Water the plants');
    });

    test(
      'a task in the bin fails as the server says and leaves the row',
      () async {
        server.beforeRequest = (_) async => throw inTrash();

        await expectLater(
          read(7),
          throwsA(isA<NotFound>().having((f) => f.code, 'code', 4040)),
        );
        expect((await db.tasksDao.find(7))?.title, 'Stale');
      },
    );

    test('a task this device is deleting stays hidden', () async {
      server.allTasks = [sampleTask(id: 7, title: 'Water the plants')];
      await (db.update(db.tasks)..where((t) => t.id.equals(7))).write(
        const TasksCompanion(pendingDelete: Value(true)),
      );

      await expectLater(
        read(7),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 4002)),
      );
    });
  });

  test('the failure texts name the bin for the task and its project', () {
    for (final l10n in [en, de]) {
      expect(taskOpenFailureText(l10n, inTrash()), l10n.taskOpenInTrash);
      expect(
        taskOpenFailureText(l10n, const NotFound(code: 3018)),
        l10n.taskOpenProjectInTrash,
      );
      expect(
        taskOpenFailureText(l10n, const NotFound(code: 4002)),
        l10n.taskOpenNotFound,
      );
      expect(
        taskOpenFailureText(l10n, const NotFound(code: 3001)),
        l10n.taskOpenNotFound,
      );
    }
  });
}
