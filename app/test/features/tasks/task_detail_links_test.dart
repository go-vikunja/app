import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/guest_app.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/team_sharing_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 12, 12);
  const link = 'https://tasks.example.org/vikunja/tasks/4';
  late SyncFakes data;
  late AuthFakes auth;
  late String? copied;
  late List<Object?> haptics;

  setUp(() {
    auth = AuthFakes();
    copied = null;
    haptics = [];
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(id: 1, title: 'Work'),
      sampleProject(
        id: 2,
        title: 'Shared',
      ).copyWith(maxPermission: Permission.read),
      sampleProject(id: 3, title: 'Old', archived: true),
    ];
    data.tasks.all = [
      sampleTask(id: 4, title: 'Ship the order'),
      sampleTask(id: 5, title: 'Read me', projectId: 2),
      sampleTask(id: 6, title: 'Kept', projectId: 3),
      sampleTask(id: -7, title: 'Not sent yet'),
      sampleTask(id: -8, title: 'Not sent, read only', projectId: 2),
    ];
  });

  void mockPlatform(WidgetTester tester, {bool copyFails = false}) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            if (copyFails) throw PlatformException(code: 'clipboard');
            copied =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          case 'HapticFeedback.vibrate':
            haptics.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }

  Future<void> pumpApp(WidgetTester tester) async {
    usePhoneSurface(tester, logicalSize: const Size(400, 1200));
    await pumpSignedInApp(tester, sync: data, auth: auth, now: now);
  }

  FakeLinkShareActions shares() => data.linkShares;

  Future<void> openDetail(WidgetTester tester, int id) async {
    final context = containerOf(tester)
        .read(appRouterProvider)
        .routerDelegate
        .navigatorKey
        .currentContext!;
    unawaited(showTaskDetail(context, task: data.tasks.find(id)!));
    await tester.pumpAndSettle();
  }

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(TaskDetailSheet), matching: finder);

  Finder sheetMenu() => inSheet(find.byTooltip(en.moreActions));

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(sheetMenu());
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, String item) async {
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  List<String> menuItems(WidgetTester tester) => [
    for (final item in tester.widgetList<PopupMenuEntry<Object?>>(
      find.byWidgetPredicate((widget) => widget is PopupMenuEntry),
    ))
      switch (item) {
        PopupMenuDivider() => '---',
        _ =>
          tester
              .widget<Text>(
                find.descendant(
                  of: find.byWidget(item),
                  matching: find.byType(Text),
                ),
              )
              .data!,
      },
  ];

  group('the menu', () {
    testWidgets('of a task the user may change: the link, then Duplicate and '
        'Delete', (tester) async {
      await pumpApp(tester);
      await openDetail(tester, 4);
      await openMenu(tester);

      expect(menuItems(tester), [
        en.taskCopyLink,
        en.taskShareLink,
        '---',
        en.taskDuplicate,
        '---',
        en.taskDelete,
      ]);
    });

    for (final (what, id) in [
      ('a project the user may only read', 5),
      ('an archived project', 6),
    ]) {
      testWidgets('in $what: only the link', (tester) async {
        await pumpApp(tester);
        await openDetail(tester, id);
        await openMenu(tester);

        expect(menuItems(tester), [en.taskCopyLink, en.taskShareLink]);
      });
    }

    testWidgets('of a task never sent: no link, which the server would not '
        'know', (tester) async {
      await pumpApp(tester);
      await openDetail(tester, -7);
      await openMenu(tester);

      expect(menuItems(tester), [en.taskDuplicate, '---', en.taskDelete]);
    });

    testWidgets('with nothing to offer, no menu at all', (tester) async {
      await pumpApp(tester);
      await openDetail(tester, -8);

      expect(inSheet(find.text('Not sent, read only')), findsWidgets);
      expect(sheetMenu(), findsNothing);
    });
  });

  group('Copy link', () {
    testWidgets("copies the web's address of the task and says so in the "
        'sheet, which stays', (tester) async {
      mockPlatform(tester);
      await pumpApp(tester);
      await openDetail(tester, 4);
      await openMenu(tester);
      await pick(tester, en.taskCopyLink);

      expect(copied, link);
      expect(inSheet(find.text(en.taskLinkCopied)), findsOneWidget);
      expect(haptics, contains('HapticFeedbackType.selectionClick'));
      expect(find.byType(TaskDetailSheet), findsOneWidget);
    });

    testWidgets('where the system confirms a copy, the app only tells the '
        'screen reader', (tester) async {
      auth.preferences.values[androidVersionKey] = '14';
      mockPlatform(tester);
      await pumpApp(tester);
      await openDetail(tester, 4);
      tester.takeAnnouncements();
      await openMenu(tester);
      await pick(tester, en.taskCopyLink);

      expect(copied, link);
      expect(inSheet(find.text(en.taskLinkCopied)), findsNothing);
      expect(
        [
          for (final announcement in tester.takeAnnouncements())
            announcement.message,
        ],
        [en.taskLinkCopied],
      );
    });

    testWidgets('a link that cannot be copied says so', (tester) async {
      mockPlatform(tester, copyFails: true);
      await pumpApp(tester);
      await openDetail(tester, 4);
      await openMenu(tester);
      await pick(tester, en.taskCopyLink);

      expect(inSheet(find.text(en.copyToClipboardFailed)), findsOneWidget);
      expect(inSheet(find.text(en.taskLinkCopied)), findsNothing);
    });

    testWidgets('in a project the user may only read', (tester) async {
      mockPlatform(tester);
      await pumpApp(tester);
      await openDetail(tester, 5);
      await openMenu(tester);
      await pick(tester, en.taskCopyLink);

      expect(copied, 'https://tasks.example.org/vikunja/tasks/5');
    });
  });

  group("the web's address", () {
    for (final (frontend, expected) in [
      ('https://app.example.org/', 'https://app.example.org/tasks/4'),
      // An http frontend for an https server is left for the server root.
      ('http://app.example.org/', link),
    ]) {
      testWidgets('with the frontend $frontend, of the task and of a '
          'comment', (tester) async {
        mockPlatform(tester);
        data.details
          ..detailsByTask[4] = const TaskDetails(
            commentCount: 1,
            maxPermission: Permission.write,
          )
          ..commentsByTask[4] = [sampleComment(id: 1)];
        usePhoneSurface(tester, logicalSize: const Size(400, 1200));
        await pumpSignedInApp(
          tester,
          sync: data,
          auth: auth,
          now: now,
          connection: accountPagesServer270(frontendUrl: Uri.parse(frontend)),
        );
        await openDetail(tester, 4);

        await openMenu(tester);
        await pick(tester, en.taskCopyLink);
        expect(copied, expected);

        final show = inSheet(find.text(en.taskDetailShowComments));
        await tester.scrollUntilVisible(
          show,
          200,
          scrollable: inSheet(find.byType(Scrollable)).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(show);
        await tester.pumpAndSettle();
        final commentMenu = inSheet(find.byTooltip(en.commentOptions('Anna')));
        await tester.ensureVisible(commentMenu);
        await tester.pumpAndSettle();
        await tester.tap(commentMenu);
        await tester.pumpAndSettle();
        await pick(tester, en.commentCopyLink);
        expect(copied, '$expected#comment-1');
      });
    }
  });

  group('Share', () {
    testWidgets("shares the web's address with the title as the subject, "
        'anchored on the menu button', (tester) async {
      await pumpApp(tester);
      await openDetail(tester, 4);
      final button = tester.getRect(
        inSheet(
          find.byWidgetPredicate(
            (widget) =>
                widget is PopupMenuButton && widget.tooltip == en.moreActions,
          ),
        ),
      );
      await openMenu(tester);
      await pick(tester, en.taskShareLink);

      expect(shares().shared, hasLength(1));
      final shared = shares().shared.single;
      expect(shared.url, Uri.parse(link));
      expect(shared.subject, 'Ship the order');
      expect(shared.origin, button);
      expect(find.byType(TaskDetailSheet), findsOneWidget);
    });

    for (final failed in [false, true]) {
      testWidgets(
        failed
            ? 'a failed share says so in the sheet'
            : 'no share sheet says so in the sheet',
        (tester) async {
          if (failed) {
            shares().failure = Exception('share');
          } else {
            shares().available = false;
          }
          await pumpApp(tester);
          await openDetail(tester, 4);
          await openMenu(tester);
          await pick(tester, en.taskShareLink);

          expect(inSheet(find.text(en.shareFailureGeneric)), findsOneWidget);
          expect(find.byType(TaskDetailSheet), findsOneWidget);
        },
      );
    }
  });

  testWidgets('a link-share guest gets Copy link and Share, as the web '
      "copies a task's link for every link share", (tester) async {
    mockPlatform(tester);
    data.projects.all = [];
    data.tasks.all = [
      sampleTask(id: 4, title: 'Water the plants', projectId: guestProjectId),
    ];
    data.details.detailsByTask[4] = const TaskDetails(
      maxPermission: Permission.read,
    );
    usePhoneSurface(tester, logicalSize: const Size(400, 1200));
    await pumpGuestApp(tester, auth: auth, data: data);
    containerOf(tester)
        .read(appRouterProvider)
        .go(AppRoutes.project(guestProjectId));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Water the plants'));
    await tester.pumpAndSettle();

    await openMenu(tester);
    expect(menuItems(tester), [en.taskCopyLink, en.taskShareLink]);
    await pick(tester, en.taskCopyLink);
    expect(copied, link);

    await openMenu(tester);
    await pick(tester, en.taskShareLink);
    expect(shares().shared.single.url, Uri.parse(link));
    expect(shares().shared.single.subject, 'Water the plants');
  });
}
