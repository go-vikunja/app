import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/share/share_intent_source.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/about/presentation/about_page.dart';
import 'package:vikunja_mobile/features/common/presentation/project_icon.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/description_editor_page.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/share/presentation/share_sheet.dart';
import 'package:vikunja_mobile/features/sync/presentation/first_sync_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/account_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../features/accounts/accounts_harness.dart';
import '../helpers/auth_fakes.dart';
import '../helpers/editor_bridge_fakes.dart';
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
    expect(data.shareLocations.removed, ['/cache/share-inbox/1']);

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

  testWidgets('on About, which lies outside /home, the share counts as '
      'signed in: About goes and the sheet opens', (tester) async {
    await pumpSignedInApp(tester, sync: data);
    unawaited(
      containerOf(tester).read(appRouterProvider).push(AppRoutes.about),
    );
    await tester.pumpAndSettle();

    data.shareSource.push(const IncomingShare(text: 'Note'));
    await tester.pumpAndSettle();

    expect(find.text(en.shareSignedOut), findsNothing);
    expect(find.byType(AboutPage), findsNothing);
    expect(sheet, findsOneWidget);
    expect(fieldText(tester, en.taskEditTitleLabel), 'Note');
  });

  testWidgets('signed out on About it says so, drops the share and About '
      'stays', (tester) async {
    await pumpVikunjaApp(tester, sync: data);
    unawaited(
      containerOf(tester).read(appRouterProvider).push(AppRoutes.about),
    );
    await tester.pumpAndSettle();

    data.shareSource.push(const IncomingShare(text: 'Note'));
    await tester.pumpAndSettle();

    expect(find.byType(AboutPage), findsOneWidget);
    expect(sheet, findsNothing);
    expect(find.text(en.shareSignedOut), findsOneWidget);
    expect(data.shareSource.calls.last, 'clear');
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

  testWidgets('dragged shut, Create answered during the closing leaves the '
      'page below open', (tester) async {
    final held = Completer<void>();
    data.tasks.beforeWrite = () => held.future;
    await pumpSignedInApp(tester, sync: data);
    data.shareSource.push(const IncomingShare(text: 'Scans'));
    await tester.pumpAndSettle();
    final router = containerOf(tester).read(appRouterProvider);
    final location = router.routerDelegate.state.matchedLocation;

    await tester.tap(action(en.shareCreate));
    await tester.pump();
    // Past half its height closes it, with the closing still to run.
    final height = tester.getSize(sheet).height;
    await tester.drag(
      inSheet(find.text(en.shareSheetTitle)),
      Offset(0, height * .7),
    );
    await tester.pump();
    expect(sheet, findsOneWidget);

    held.complete();
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(data.tasks.writes, ['create -1 Scans']);
    expect(router.routerDelegate.state.matchedLocation, location);
    expect(find.text(en.shareTaskCreated(0)), findsOneWidget);
  });

  testWidgets('dragged shut, a Create that fails during the closing says so, '
      'as nothing else shows it', (tester) async {
    final held = Completer<void>();
    data.tasks.beforeWrite = () => held.future;
    await pumpSignedInApp(tester, sync: data);
    data.shareSource.push(const IncomingShare(text: 'Scans'));
    await tester.pumpAndSettle();

    await tester.tap(action(en.shareCreate));
    await tester.pump();
    final height = tester.getSize(sheet).height;
    await tester.drag(
      inSheet(find.text(en.shareSheetTitle)),
      Offset(0, height * .7),
    );
    await tester.pump();

    held.completeError(StateError('the database went away'));
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(data.tasks.writes, ['create -1 Scans']);
    expect(data.shareSource.calls.last, 'clear');
    expect(find.text(en.shareFailed), findsOneWidget);
  });

  testWidgets('a Create that failed in the open sheet is not reported again '
      'once the sheet is closed', (tester) async {
    data.tasks.beforeWrite = () async =>
        throw StateError('the database went away');
    await pumpSignedInApp(tester, sync: data);
    data.shareSource.push(const IncomingShare(text: 'Scans'));
    await tester.pumpAndSettle();

    await tester.tap(action(en.shareCreate));
    await tester.pumpAndSettle();
    expect(inSheet(find.text(en.shareFailed)), findsOneWidget);

    final height = tester.getSize(sheet).height;
    await tester.drag(
      inSheet(find.text(en.shareSheetTitle)),
      Offset(0, height * .7),
    );
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(find.text(en.shareFailed), findsNothing);
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

  testWidgets('a file whose location could not be removed says so on its '
      'row before anything is uploaded, and goes only when the user chooses '
      'Upload; Skip leaves it out', (tester) async {
    // Each share's copy of the file.
    for (final copy in ['/cache/share-inbox/1', '/cache/share-inbox/2']) {
      data.shareLocations.failures[copy] = PlatformException(
        code: 'remove_location_failed',
      );
    }
    await pumpSignedInApp(tester, sync: data);
    for (final (choice, id, uploaded) in [
      (en.attachmentLocationKeptSkip, -1, false),
      (en.attachmentLocationKeptUpload, -2, true),
    ]) {
      data.tasks.writes.clear();
      data.shareSource.push(const IncomingShare(text: 'Files', files: [_list]));
      await tester.pumpAndSettle();

      expect(
        inSheet(find.text(en.shareFileLocationKept('2 KB'))),
        findsOneWidget,
      );
      // The sheet shows its progress while the question is up.
      await tester.tap(action(en.shareCreate));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(en.attachmentLocationKeptTitle), findsOneWidget);
      expect(data.tasks.writes, isEmpty);
      await tester.tap(find.text(choice));
      await tester.pumpAndSettle();

      expect(data.tasks.writes, [
        'create $id Files',
        if (uploaded) 'queueUpload $id list.pdf move',
      ], reason: choice);
    }
  });

  testWidgets('Add to task with only a file whose location stayed: Skip '
      'leaves nothing to add, so the sheet stays without the file, and Add '
      'neither asks again nor fails', (tester) async {
    data.shareLocations.failures['/cache/share-inbox/1'] = PlatformException(
      code: 'remove_location_failed',
    );
    await pumpSignedInApp(tester, sync: data);
    data.shareSource.push(const IncomingShare(files: [_list]));
    await tester.pumpAndSettle();
    await tester.tap(inSheet(find.text(en.shareAddToTask)));
    await tester.pumpAndSettle();
    await tester.enterText(field(en.addRelationSearch), 'water');
    await tester.pumpAndSettle();
    await tester.tap(inSheet(find.text('Water the plants')));
    await tester.pumpAndSettle();

    await tester.tap(action(en.shareAdd));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(en.attachmentLocationKeptSkip));
    await tester.pumpAndSettle();

    expect(data.tasks.writes, isEmpty);
    expect(sheet, findsOneWidget);
    expect(find.text(en.shareAddedToTask(0)), findsNothing);
    expect(inSheet(find.text('list.pdf')), findsNothing);
    expect(enabled(tester, en.shareAdd), isFalse);
  });

  testWidgets('after Skip and a Create that failed, the next Create neither '
      'asks about the skipped file again nor fails on it', (tester) async {
    data.shareLocations.failures['/cache/share-inbox/1'] = PlatformException(
      code: 'remove_location_failed',
    );
    var failing = true;
    data.tasks.beforeWrite = () async {
      if (failing) throw StateError('the database went away');
    };
    await pumpSignedInApp(tester, sync: data);
    data.shareSource.push(const IncomingShare(text: 'Scan', files: [_list]));
    await tester.pumpAndSettle();

    await tester.tap(action(en.shareCreate));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(en.attachmentLocationKeptSkip));
    await tester.pumpAndSettle();
    expect(inSheet(find.text(en.shareFailed)), findsOneWidget);
    expect(inSheet(find.text('list.pdf')), findsNothing);

    failing = false;
    await tapAction(tester, en.shareCreate);

    expect(find.text(en.attachmentLocationKeptTitle), findsNothing);
    // The failed create is recorded before it throws.
    expect(data.tasks.writes, ['create -1 Scan', 'create -2 Scan']);
    expect(sheet, findsNothing);
    expect(find.text(en.shareTaskCreated(0)), findsOneWidget);
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

  testWidgets('an account that can only read its projects says it cannot '
      'take the share and offers nothing that would not work', (tester) async {
    data.projects.all = [
      sampleProject(
        id: 1,
        title: 'Work',
      ).copyWith(maxPermission: Permission.read),
    ];
    await pumpSignedInApp(tester, sync: data);
    data.shareSource.push(
      const IncomingShare(text: 'Buy milk', files: [_list]),
    );
    await tester.pumpAndSettle();

    expect(inSheet(find.text(en.shareReadOnlyAccount)), findsOneWidget);
    expect(enabled(tester, en.shareCreate), isFalse);
    expect(inSheet(find.text(en.shareAddToTask)), findsNothing);
    expect(inSheet(find.byType(TextField)), findsNothing);
    expect(inSheet(find.text('list.pdf')), findsNothing);

    await tester.tap(inSheet(find.byTooltip(en.cancel)));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(data.tasks.writes, isEmpty);
    expect(data.shareSource.calls.last, 'clear');
  });

  testWidgets('a file the other app never delivers: Cancel closes at once, '
      'and the next share opens though the platform never answers the '
      'clear', (tester) async {
    final never = Completer<void>();
    await pumpSignedInApp(tester, sync: data);
    data.shareSource.beforeCall = (call) =>
        call.startsWith('copy') || call == 'clear'
        ? never.future
        : Future.value();
    data.shareSource.push(const IncomingShare(text: 'First', files: [_list]));
    // The row's progress never settles.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(inSheet(find.text(en.shareFilePreparing)), findsOneWidget);

    await tester.tap(inSheet(find.byTooltip(en.cancel)));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(data.shareSource.calls.last, 'clear');

    data.shareSource.beforeCall = null;
    data.shareSource.push(const IncomingShare(text: 'Second'));
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    expect(sheet, findsOneWidget);
    expect(fieldText(tester, en.taskEditTitleLabel), 'Second');
  });

  testWidgets('a newer share replaces the one on screen without waiting for '
      'its clear', (tester) async {
    const first = IncomingShare(id: 1, text: 'First');
    const second = IncomingShare(id: 2, text: 'Second');
    final clearing = Completer<void>();
    await pumpSignedInApp(tester, sync: data);
    data.shareSource.push(first);
    await tester.pumpAndSettle();

    data.shareSource.beforeCall = (call) async {
      if (call == 'clear') await clearing.future;
    };
    data.shareSource.push(second);
    await tester.pumpAndSettle();

    expect(sheet, findsOneWidget);
    expect(fieldText(tester, en.taskEditTitleLabel), 'Second');
    expect(data.shareSource.clearedShares, [first]);
    clearing.complete();
    await tester.pumpAndSettle();
    expect(await data.shareSource.pending(), second);
  });

  testWidgets('a superseded share is cleared only after its submitted '
      'files move, not when the next share arrives', (tester) async {
    const first = IncomingShare(id: 1, text: 'First', files: [_list, _other]);
    const second = IncomingShare(id: 2, text: 'Second', files: [_list]);
    final held = Completer<void>();
    var writes = 0;
    data.tasks.beforeWrite = () async {
      if (++writes == 2) await held.future;
    };
    await pumpSignedInApp(tester, sync: data);
    data.shareSource.push(first);
    await tester.pumpAndSettle();

    await tester.tap(action(en.shareCreate));
    await tester.pump();
    Navigator.of(tester.element(sheet)).pop();
    await tester.pumpAndSettle();
    data.shareSource.push(second);
    await tester.pumpAndSettle();
    expect(data.shareSource.clearedShares, isEmpty);

    held.complete();
    await tester.pumpAndSettle();
    expect(data.tasks.writes, [
      'create -1 First',
      'queueUpload -1 list.pdf move',
      'queueUpload -1 notes.txt move',
    ]);
    expect(data.shareSource.clearedShares, [first]);
    expect(fieldText(tester, en.taskEditTitleLabel), 'Second');
    expect(inSheet(find.text('list.pdf')), findsOneWidget);
  });

  group('over a New task sheet with a title typed', () {
    final newTask = find.byType(NewTaskSheet);

    Future<void> typeNewTask(WidgetTester tester) async {
      await pumpSignedInApp(tester, sync: data);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(of: newTask, matching: find.byType(TextField)),
        'Buy milk',
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a share asks first; Keep editing keeps the sheet, says so '
        'and drops the share', (tester) async {
      await typeNewTask(tester);

      data.shareSource.push(const IncomingShare(text: 'Note'));
      await tester.pumpAndSettle();
      expect(find.text(en.newTaskDiscardTitle), findsOneWidget);
      await tester.tap(find.text(en.taskEditKeepEditing));
      await tester.pumpAndSettle();

      expect(newTask, findsOneWidget);
      expect(find.widgetWithText(TextField, 'Buy milk'), findsOneWidget);
      expect(find.text(en.shareKeptEditing), findsOneWidget);
      expect(sheet, findsNothing);
      expect(data.shareSource.calls.last, 'clear');
    });

    testWidgets('Discard there lets the sheet go and the share sheet opens', (
      tester,
    ) async {
      await typeNewTask(tester);

      data.shareSource.push(const IncomingShare(text: 'Note'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.taskEditDiscard));
      await tester.pumpAndSettle();

      expect(newTask, findsNothing);
      expect(sheet, findsOneWidget);
      expect(fieldText(tester, en.taskEditTitleLabel), 'Note');
      expect(find.text(en.shareKeptEditing), findsNothing);
    });

    testWidgets('a newer share during that question keeps the New task sheet '
        'and its title and asks again', (tester) async {
      await typeNewTask(tester);

      data.shareSource.push(const IncomingShare(text: 'First'));
      await tester.pumpAndSettle();
      expect(find.text(en.newTaskDiscardTitle), findsOneWidget);

      data.shareSource.push(const IncomingShare(text: 'Second'));
      await tester.pumpAndSettle();
      expect(find.text(en.newTaskDiscardTitle), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Buy milk'), findsOneWidget);
      expect(find.text(en.shareKeptEditing), findsNothing);

      await tester.tap(find.text(en.taskEditDiscard));
      await tester.pumpAndSettle();

      expect(newTask, findsNothing);
      expect(sheet, findsOneWidget);
      expect(fieldText(tester, en.taskEditTitleLabel), 'Second');
      expect(data.shareSource.clearedShares, [
        const IncomingShare(text: 'First'),
      ]);
    });
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

    testWidgets('over an edit page with unsaved changes the page asks before '
        'the switch; Keep editing keeps it and drops the share with a '
        'note', (tester) async {
      await accounts.seed();
      accounts.aliceData.projects.all = data.projects.all;
      accounts.aliceData.tasks.all = data.tasks.all;
      usePhoneSurface(tester, logicalSize: const Size(360, 2200));
      await accounts.pump(tester);
      final router = containerOf(tester).read(appRouterProvider);
      unawaited(router.push(AppRoutes.taskEdit(7)));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, en.taskEditTitleLabel),
        'Changed',
      );
      await tester.pumpAndSettle();

      accounts.data.shareSource.push(const IncomingShare(text: 'Seeds'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AccountPickerSheet),
          matching: find.text('Bob'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(en.taskEditDiscardTitle), findsOneWidget);

      await tester.tap(find.text(en.taskEditKeepEditing));
      await tester.pumpAndSettle();

      expect(
        containerOf(tester).read(accountsProvider).value!.activeAccountId,
        accounts.alice.id,
      );
      expect(router.state.matchedLocation, AppRoutes.taskEdit(7));
      expect(find.widgetWithText(TextField, 'Changed'), findsOneWidget);
      expect(sheet, findsNothing);
      expect(find.text(en.shareKeptEditing), findsOneWidget);
      expect(accounts.data.shareSource.calls.last, 'clear');
    });

    testWidgets('a page that was left but takes too long to go drops the '
        'share without the note', (tester) async {
      final bridges = FakeEditorBridges();
      await accounts.seed();
      accounts.aliceData.projects.all = data.projects.all;
      accounts.aliceData.tasks.all = data.tasks.all;
      usePhoneSurface(tester, logicalSize: const Size(360, 2200));
      await accounts.pump(tester, overrides: [bridges.override]);
      unawaited(
        containerOf(tester)
            .read(appRouterProvider)
            .push(AppRoutes.projectDescription(1)),
      );
      await tester.pumpAndSettle();
      bridges.last.edit('<p>Edited</p>');
      await tester.pump();
      final saved = Completer<void>();
      accounts.aliceData.projects.beforeCall = (_) => saved.future;

      accounts.data.shareSource.push(const IncomingShare(text: 'Seeds'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AccountPickerSheet),
          matching: find.text('Bob'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(en.descriptionEditorLeaveTitle), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text(en.taskEditSave),
        ),
      );
      await tester.pump(const Duration(seconds: 31));
      await pumpFrames(tester, 5);

      expect(find.text(en.shareKeptEditing), findsNothing);
      expect(accounts.data.shareSource.calls.last, 'clear');
      expect(sheet, findsNothing);

      saved.complete();
      await tester.pumpAndSettle();
      expect(accounts.aliceData.projects.byId(1)?.description, '<p>Edited</p>');
      expect(find.byType(DescriptionEditorPage), findsNothing);
      expect(
        containerOf(tester).read(accountsProvider).value!.activeAccountId,
        accounts.alice.id,
      );
      expect(sheet, findsNothing);
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
