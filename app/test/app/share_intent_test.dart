import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/share/share_intent_source.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/common/presentation/project_icon.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/share/presentation/share_sheet.dart';
import 'package:vikunja_mobile/features/sync/presentation/first_sync_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/account_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../features/accounts/accounts_harness.dart';
import '../helpers/auth_fakes.dart';
import '../helpers/pump_app.dart';
import '../helpers/sample_data.dart';
import '../helpers/server_connections.dart';
import '../helpers/sync_fakes.dart';

const int _mib = 1024 * 1024;
const _link = 'target="_blank" rel="noopener noreferrer nofollow"';

const _list = SharedFile(
  uri: 'content://files.example/1',
  displayName: 'list.pdf',
  size: 2048,
  mimeType: 'application/pdf',
);
const _other = SharedFile(
  uri: 'content://files.example/3',
  displayName: 'notes.txt',
  size: 10,
  mimeType: 'text/plain',
);
const _huge = SharedFile(
  uri: 'content://files.example/2',
  displayName: 'huge.mov',
  size: 30 * _mib,
  mimeType: 'video/mp4',
);

void main() {
  late SyncFakes data;

  setUp(() {
    data = SyncFakes();
    data.projects.all = [sampleProject(id: 1, title: 'Work')];
    data.tasks.all = [
      sampleTask(
        id: 7,
        title: 'Water the plants',
        description: '<p>Every week</p>',
      ),
    ];
  });

  final sheet = find.byType(ShareSheet);

  Finder inSheet(Finder matching) =>
      find.descendant(of: sheet, matching: matching);

  Finder field(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextField));

  String fieldText(WidgetTester tester, String label) =>
      tester.widget<TextField>(field(label)).controller!.text;

  Finder action(String label) =>
      inSheet(find.widgetWithText(TextButton, label));

  bool enabled(WidgetTester tester, String label) =>
      tester.widget<TextButton>(action(label)).onPressed != null;

  Future<void> tapAction(WidgetTester tester, String label) async {
    await tester.tap(action(label));
    await tester.pumpAndSettle();
  }

  testWidgets('a share that started the app becomes a new task with its '
      'text, project and files', (tester) async {
    data.projects.all = [
      sampleProject(id: 1, title: 'Work', hexColor: '1973ff'),
    ];
    data.shareSource.push(
      const IncomingShare(
        text: 'Buy milk\nand bread https://shop.example/x',
        files: [_list, _huge],
      ),
    );
    await pumpSignedInApp(tester, sync: data);

    expect(sheet, findsOneWidget);
    expect(fieldText(tester, en.taskEditTitleLabel), 'Buy milk');
    expect(
      fieldText(tester, en.taskDetailDescription),
      'and bread https://shop.example/x',
    );
    expect(inSheet(find.text('Work')), findsOneWidget);
    expect(
      tester.widget<ProjectIcon>(inSheet(find.byType(ProjectIcon))).hexColor,
      '1973ff',
    );
    expect(inSheet(find.text('list.pdf')), findsOneWidget);
    expect(inSheet(find.text('2 KB')), findsOneWidget);
    expect(inSheet(find.text(en.shareFileTooLarge('20 MB'))), findsOneWidget);
    // Known to be too large, so not copied.
    expect(data.shareSource.calls, [
      'pending',
      'copy content://files.example/1 max ${20 * _mib}',
    ]);

    await tapAction(tester, en.shareCreate);

    expect(data.tasks.creates.single.title, 'Buy milk');
    expect(data.tasks.creates.single.projectId, 1);
    expect(
      data.tasks.creates.single.description,
      '<p>and bread <a $_link '
      'href="https://shop.example/x">https://shop.example/x</a></p>',
    );
    expect(data.tasks.uploadRequests, [
      (
        taskId: -1,
        sourcePath: '/cache/share-inbox/1',
        fileName: 'list.pdf',
        mimeType: 'application/pdf',
        moveSource: true,
      ),
    ]);
    expect(data.shareSource.calls.last, 'clear');
    expect(sheet, findsNothing);
    expect(find.text(en.shareTaskCreated(1)), findsOneWidget);

    await tester.tap(find.text(en.taskDuplicateOpen));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(TaskDetailSheet),
        matching: find.text('Buy milk'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a browser share takes the page title as the title', (
    tester,
  ) async {
    await pumpSignedInApp(tester, sync: data);

    data.shareSource.push(
      const IncomingShare(subject: 'Release notes', text: 'https://x.org/n'),
    );
    await tester.pumpAndSettle();

    expect(fieldText(tester, en.taskEditTitleLabel), 'Release notes');
    expect(fieldText(tester, en.taskDetailDescription), 'https://x.org/n');
    expect(inSheet(find.text(en.shareFiles)), findsNothing);
  });

  testWidgets('waits for the first sync', (tester) async {
    final auth = AuthFakes();
    await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    final sync = SyncFakes(status: const SyncNeverRun());
    sync.projects.all = data.projects.all;
    sync.shareSource.push(const IncomingShare(text: 'Later'));
    final firstSync = Completer<void>();
    sync.engine.onEnsureInitialSync = () => firstSync.future;
    await pumpVikunjaApp(tester, auth: auth, sync: sync, settle: false);
    await pumpUntil(tester, find.byType(FirstSyncScreen));
    await pumpFrames(tester, 3);
    expect(sheet, findsNothing);

    firstSync.complete();
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget);
    expect(fieldText(tester, en.taskEditTitleLabel), 'Later');
  });

  testWidgets('signed out it says so and drops the share', (tester) async {
    data.shareSource.push(const IncomingShare(text: 'Note'));
    await pumpVikunjaApp(tester, sync: data);

    expect(find.byType(ConnectServerScreen), findsOneWidget);
    expect(sheet, findsNothing);
    expect(find.text(en.shareSignedOut), findsOneWidget);
    expect(data.shareSource.calls, ['pending', 'clear']);
  });

  testWidgets('Cancel writes nothing and deletes the inbox copies', (
    tester,
  ) async {
    await pumpSignedInApp(tester, sync: data);
    data.shareSource.push(const IncomingShare(text: 'x', files: [_list]));
    await tester.pumpAndSettle();

    await tester.tap(inSheet(find.byTooltip(en.cancel)));
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(data.tasks.writes, isEmpty);
    expect(data.shareSource.calls.last, 'clear');
  });

  testWidgets('while Create runs the sheet stays; dragged away, the files '
      'still move before the inbox is cleared', (tester) async {
    final held = Completer<void>();
    var writes = 0;
    data.tasks.beforeWrite = () async {
      if (++writes == 2) await held.future;
    };
    await pumpSignedInApp(tester, sync: data);
    data.shareSource.push(
      const IncomingShare(text: 'Scans', files: [_list, _other]),
    );
    await tester.pumpAndSettle();

    await tester.tap(action(en.shareCreate));
    await tester.pump();
    final close = inSheet(
      find.ancestor(
        of: find.byTooltip(en.cancel),
        matching: find.byType(IconButton),
      ),
    );
    expect(tester.widget<IconButton>(close).onPressed, isNull);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(sheet, findsOneWidget);

    // A drag closes the material sheet without asking.
    Navigator.of(tester.element(sheet)).pop();
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(data.shareSource.calls, isNot(contains('clear')));

    held.complete();
    await tester.pumpAndSettle();
    expect(data.tasks.writes, [
      'create -1 Scans',
      'queueUpload -1 list.pdf move',
      'queueUpload -1 notes.txt move',
    ]);
    expect(data.shareSource.calls.last, 'clear');
    expect(find.text(en.shareTaskCreated(2)), findsOneWidget);
  });

  testWidgets('Add to task keeps the shared text field while it is emptied '
      'to be typed over', (tester) async {
    await pumpSignedInApp(tester, sync: data);
    data.shareSource.push(
      const IncomingShare(text: 'A caption', files: [_list]),
    );
    await tester.pumpAndSettle();
    await tester.tap(inSheet(find.text(en.shareAddToTask)));
    await tester.pumpAndSettle();

    await tester.enterText(field(en.taskDetailDescription), '');
    await tester.pump();
    expect(field(en.taskDetailDescription), findsOneWidget);
    await tester.enterText(field(en.taskDetailDescription), 'My words');
    await tester.pump();

    expect(fieldText(tester, en.taskDetailDescription), 'My words');
  });

  testWidgets('Add to task finds a task on this device and appends the text '
      'after the stored description; files go to it', (tester) async {
    await pumpSignedInApp(tester, sync: data);
    data.shareSource.push(
      const IncomingShare(
        subject: 'Page',
        text: 'https://x.org/a',
        files: [_list],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(inSheet(find.text(en.shareAddToTask)));
    await tester.pumpAndSettle();
    expect(
      fieldText(tester, en.taskDetailDescription),
      'Page\nhttps://x.org/a',
    );
    expect(inSheet(find.text(en.sharePickTask)), findsOneWidget);
    expect(enabled(tester, en.shareAdd), isFalse);

    await tester.enterText(field(en.addRelationSearch), 'water');
    await tester.pumpAndSettle();
    // The candidate names its project, not its number (#7).
    final candidate = inSheet(
      find.widgetWithText(ListTile, 'Water the plants'),
    );
    expect(
      find.descendant(of: candidate, matching: find.text('Work')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: candidate, matching: find.textContaining('#')),
      findsNothing,
    );
    await tester.tap(inSheet(find.text('Water the plants')));
    await tester.pumpAndSettle();
    expect(enabled(tester, en.shareAdd), isTrue);
    await tapAction(tester, en.shareAdd);

    expect(data.tasks.descriptionUpdates, [
      (
        7,
        '<p>Every week</p><p>Page<br><a $_link '
            'href="https://x.org/a">https://x.org/a</a></p>',
        '<p>Every week</p>',
      ),
    ]);
    expect(data.tasks.writes, [
      'updateDescription 7',
      'queueUpload 7 list.pdf move',
    ]);
    expect(find.text(en.shareAddedToTask(1)), findsOneWidget);
    expect(data.shareSource.calls.last, 'clear');
  });

  testWidgets('a file can be left out; one that cannot be read is flagged '
      'and never queued', (tester) async {
    const other = SharedFile(
      uri: 'content://files.example/3',
      displayName: 'gone.txt',
    );
    data.shareSource.copyFailures[other.uri] = const SharedFileUnreadable();
    await pumpSignedInApp(tester, sync: data);
    data.shareSource.push(
      const IncomingShare(text: 'Files', files: [_list, other]),
    );
    await tester.pumpAndSettle();

    expect(inSheet(find.text(en.shareFileUnreadable)), findsOneWidget);
    await tester.tap(inSheet(find.byTooltip(en.shareRemoveFile('list.pdf'))));
    await tester.pumpAndSettle();
    expect(inSheet(find.text('list.pdf')), findsNothing);
    await tapAction(tester, en.shareCreate);

    expect(data.tasks.writes, ['create -1 Files']);
    expect(find.text(en.shareTaskCreated(0)), findsOneWidget);
  });

  testWidgets('a server without attachments takes the text; the files are '
      'left out', (tester) async {
    data.attachments.uploadsEnabled = false;
    await pumpSignedInApp(tester, sync: data);
    data.shareSource.push(const IncomingShare(text: 'Scan', files: [_list]));
    await tester.pumpAndSettle();

    expect(inSheet(find.text(en.shareFilesLeftOut)), findsOneWidget);
    expect(
      data.shareSource.calls.where((call) => call.startsWith('copy')),
      isEmpty,
    );
    await tapAction(tester, en.shareCreate);
    expect(data.tasks.writes, ['create -1 Scan']);
  });

  testWidgets('offline everything is queued as usual', (tester) async {
    await pumpSignedInApp(tester, sync: data);
    data.engine.emit(
      SyncFailed(
        failure: const NetworkFailure(NetworkProblem.unreachable),
        lastSyncedAt: DateTime.now(),
      ),
    );
    await tester.pumpAndSettle();
    data.shareSource.push(const IncomingShare(text: 'Offline', files: [_list]));
    await tester.pumpAndSettle();

    await tapAction(tester, en.shareCreate);

    expect(data.tasks.writes, [
      'create -1 Offline',
      'queueUpload -1 list.pdf move',
    ]);
  });

  testWidgets('without a title nothing can be created; more than 20 files '
      'are cut', (tester) async {
    await pumpSignedInApp(tester, sync: data);
    data.shareSource.push(
      IncomingShare(
        files: [
          for (var i = 0; i < 21; i++)
            SharedFile(uri: 'content://f/$i', displayName: '$i.jpg', size: 1),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(fieldText(tester, en.taskEditTitleLabel), '');
    expect(enabled(tester, en.shareCreate), isFalse);
    expect(inSheet(find.text(en.shareTooManyFiles(20))), findsOneWidget);
    expect(
      data.shareSource.calls.where((call) => call.startsWith('copy')),
      hasLength(20),
    );
  });

  testWidgets('a newer share replaces the one on screen', (tester) async {
    await pumpSignedInApp(tester, sync: data);
    data.shareSource.push(const IncomingShare(text: 'First'));
    await tester.pumpAndSettle();

    data.shareSource.push(const IncomingShare(text: 'Second'));
    await tester.pumpAndSettle();

    expect(sheet, findsOneWidget);
    expect(fieldText(tester, en.taskEditTitleLabel), 'Second');
    expect(data.shareSource.calls.where((call) => call == 'clear'), isEmpty);
  });

  group('with several accounts', () {
    late ThreeAccounts accounts;

    setUp(() => accounts = ThreeAccounts());

    testWidgets('the user picks the account first, which becomes active', (
      tester,
    ) async {
      await accounts.seed();
      accounts.bobData.projects.all = [sampleProject(id: 3, title: 'Garden')];
      await accounts.pump(tester);

      accounts.data.shareSource.push(const IncomingShare(text: 'Seeds'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountPickerSheet), findsOneWidget);
      expect(find.text(en.sharePickAccountTitle), findsOneWidget);
      expect(sheet, findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(AccountPickerSheet),
          matching: find.text('Bob'),
        ),
      );
      await tester.pumpAndSettle();

      final container = containerOf(tester);
      expect(
        container.read(accountsProvider).value!.activeAccountId,
        accounts.bob.id,
      );
      expect(inSheet(find.text('Garden')), findsOneWidget);
      await tapAction(tester, en.shareCreate);
      expect(accounts.bobData.tasks.writes, ['create -1 Seeds']);
      expect(accounts.aliceData.tasks.writes, isEmpty);
    });

    testWidgets('closing the question drops the share', (tester) async {
      await accounts.seed();
      await accounts.pump(tester);

      accounts.data.shareSource.push(const IncomingShare(text: 'Seeds'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(sheet, findsNothing);
      expect(accounts.data.shareSource.calls.last, 'clear');
      expect(
        containerOf(tester).read(accountsProvider).value!.activeAccountId,
        accounts.alice.id,
      );
    });
  });
}
