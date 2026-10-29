import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/platform/app_backgrounding.dart';
import 'package:vikunja_mobile/core/platform/recents_screenshots.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';
import 'package:vikunja_mobile/core/security/app_lock_controller.dart';
import 'package:vikunja_mobile/core/security/device_authenticator.dart';
import 'package:vikunja_mobile/core/security/privacy_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';
import 'package:vikunja_mobile/core/security/screen_protection.dart';
import 'package:vikunja_mobile/core/share/share_intent_source.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/share/presentation/share_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comment_composer.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../helpers/announcer_region.dart';
import '../helpers/app_lock_fakes.dart';
import '../helpers/auth_fakes.dart';
import '../helpers/large_screens.dart';
import '../helpers/notification_ui_fakes.dart';
import '../helpers/pump_app.dart';
import '../helpers/sample_data.dart';
import '../helpers/sync_fakes.dart';
import '../helpers/task_detail_panes.dart';

const _lockOn = PrivacySettings(appLock: true);
const _immediately = PrivacySettings(
  appLock: true,
  lockAfter: LockAfter.immediately,
);
const _belowTheLock = 'A page below the lock';

void main() {
  late AuthFakes auth;
  late SyncFakes data;
  late FakeDeviceAuthenticator device;
  late NotificationFakes notifications;
  late _RecordingBackgrounding backgrounding;
  late DateTime now;

  /// What the framework told the platform about handling back, in order.
  late List<bool> backReports;

  setUp(() {
    auth = AuthFakes();
    data = SyncFakes();
    data.projects.all = [sampleProject(id: 1, title: 'Work')];
    data.tasks.all = [sampleTask(id: 7, title: 'Water the plants')];
    device = FakeDeviceAuthenticator();
    notifications = NotificationFakes();
    backgrounding = _RecordingBackgrounding();
    now = DateTime.utc(2026, 10, 27, 9);
    backReports = [];
  });

  void lifecycle(WidgetTester tester, List<AppLifecycleState> states) =>
      states.forEach(tester.binding.handleAppLifecycleStateChanged);

  Future<void> leave(WidgetTester tester) async {
    lifecycle(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    await tester.pump();
  }

  Future<void> comeBack(WidgetTester tester) async {
    lifecycle(tester, const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    await pumpPastPromptSettle(tester);
    await tester.pumpAndSettle();
  }

  /// Signed in, resumed, with [settings] stored before the start, and past
  /// the moment the lock waits before it prompts on its own.
  Future<void> start(
    WidgetTester tester, {
    PrivacySettings settings = _lockOn,
    RecentsScreenshots? recents,
  }) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
          backReports.add(call.arguments as bool);
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
    await storePrivacySettings(auth.preferences, settings);
    await pumpSignedInApp(
      tester,
      auth: auth,
      sync: data,
      notifications: notifications,
      overrides: [
        deviceAuthenticatorProvider.overrideWithValue(device),
        appBackgroundingProvider.overrideWithValue(backgrounding),
        clockProvider.overrideWithValue(() => now),
        if (recents != null)
          recentsScreenshotsProvider.overrideWithValue(recents),
      ],
    );
    await pumpPastPromptSettle(tester);
    await tester.pumpAndSettle();
  }

  GoRouter routerOf(WidgetTester tester) =>
      containerOf(tester).read(appRouterProvider);

  AppLockState lockState(WidgetTester tester) =>
      containerOf(tester).read(appLockControllerProvider);

  /// Whether a screen reader finds [label] in the live semantics tree; a
  /// render object's last semantics node stays around once excluded.
  bool announced(WidgetTester tester, String label) {
    var found = false;
    bool visit(SemanticsNode node) {
      found |= node.label.contains(label);
      if (!found) node.visitChildren(visit);
      return !found;
    }

    visit(
      tester
          .binding
          .renderViews
          .single
          .owner!
          .semanticsOwner!
          .rootSemanticsNode!,
    );
    return found;
  }

  final lockScreen = find.text(en.appLockTitle);
  final unlockButton = find.widgetWithText(FilledButton, en.appLockUnlock);
  final privacyCover = find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_PrivacyCover',
  );

  /// The page the user had open: a route that back would pop.
  Future<void> pushPageBelow(WidgetTester tester) async {
    routerOf(tester).routerDelegate.navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text(_belowTheLock)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// With "Immediately", out of sight and back, the prompt held open.
  Future<void> lockAgain(WidgetTester tester) async {
    device.holdPrompts = true;
    await leave(tester);
    await comeBack(tester);
    expect(lockScreen, findsOneWidget);
  }

  group('the lock screen', () {
    testWidgets('covers the app from the first frame of a cold start; the '
        'app below gets no pointers, focus, semantics or tickers', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      device.holdPrompts = true;
      await start(tester);

      expect(lockScreen, findsOneWidget);
      expect(device.prompts, 1);
      expect(announced(tester, en.appLockTitle), isTrue);
      final tab = find.text(en.tabAccount);
      expect(tab, findsOneWidget);
      expect(announced(tester, en.tabAccount), isFalse);
      final tabContext = tester.element(tab);
      expect(Focus.of(tabContext).canRequestFocus, isFalse);
      expect(TickerMode.valuesOf(tabContext).enabled, isFalse);
      await tester.tap(tab, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(routerOf(tester).state.matchedLocation, AppRoutes.overview);

      device.finish(DeviceAuthResult.success);
      await tester.pumpAndSettle();

      expect(lockScreen, findsNothing);
      expect(announced(tester, en.tabAccount), isTrue);
      expect(Focus.of(tester.element(tab)).canRequestFocus, isTrue);
      expect(TickerMode.valuesOf(tester.element(tab)).enabled, isTrue);
      await tester.tap(tab);
      await tester.pumpAndSettle();
      expect(routerOf(tester).state.matchedLocation, AppRoutes.account);
      semantics.dispose();
    });

    testWidgets('Unlock prompts again after a cancel; a lockout and other '
        'failures say so and stay locked', (tester) async {
      device.result = DeviceAuthResult.cancelled;
      await start(tester);
      expect(lockScreen, findsOneWidget);
      expect(device.prompts, 1);

      await tester.tap(unlockButton);
      await tester.pumpAndSettle();
      expect(device.prompts, 2);
      expect(lockScreen, findsOneWidget);

      device.result = DeviceAuthResult.lockedOut;
      await tester.tap(unlockButton);
      await tester.pumpAndSettle();
      expect(find.text(en.appLockLockedOut), findsOneWidget);

      device.result = DeviceAuthResult.unavailable;
      await tester.tap(unlockButton);
      await tester.pumpAndSettle();
      expect(find.text(en.appLockLockedOut), findsNothing);
      expect(find.text(en.appLockUnavailable), findsOneWidget);
      expect(lockScreen, findsOneWidget);

      device.result = DeviceAuthResult.inProgress;
      await tester.tap(unlockButton);
      await tester.pumpAndSettle();
      expect(find.text(en.appLockPromptStuck), findsOneWidget);

      device.result = DeviceAuthResult.success;
      await tester.tap(unlockButton);
      await tester.pumpAndSettle();
      expect(lockScreen, findsNothing);
      expect(device.prompts, 6);
    });

    testWidgets('Unlock is disabled while the system prompt is up', (
      tester,
    ) async {
      device.holdPrompts = true;
      await start(tester);

      expect(tester.widget<ButtonStyleButton>(unlockButton).enabled, isFalse);
      device.finish(DeviceAuthResult.cancelled);
      await tester.pumpAndSettle();
      expect(tester.widget<ButtonStyleButton>(unlockButton).enabled, isTrue);
    });

    testWidgets('a device without a screen lock any more turns the lock off '
        'and says so once', (tester) async {
      device.result = DeviceAuthResult.noCredentials;
      await start(tester);

      expect(lockScreen, findsNothing);
      expect(find.text(en.appLockTurnedOff), findsOneWidget);
      expect(lockState(tester).notice, isNull);
      final stored = await containerOf(tester)
          .read(privacySettingsProvider.future);
      expect(stored.appLock, isFalse);
    });

    testWidgets('gives the status bar icons that read on the lock screen, '
        'whatever the page below asks for', (tester) async {
      await start(tester, settings: _immediately);
      routerOf(tester).routerDelegate.navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF000000),
              title: const Text(_belowTheLock),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Brightness? statusBarIcons() {
        final view = tester.binding.renderViews.single;
        return view.debugLayer!
            .find<SystemUiOverlayStyle>(Offset(view.paintBounds.center.dx, 0))
            ?.statusBarIconBrightness;
      }

      expect(statusBarIcons(), Brightness.light);

      await lockAgain(tester);
      expect(statusBarIcons(), Brightness.dark);

      device.finish(DeviceAuthResult.success);
      await tester.pumpAndSettle();
      expect(statusBarIcons(), Brightness.light);
    });

    // Flutter applies the last style again when the app returns, which
    // below Android 11 clears dark navigation bar icons it does not name.
    testWidgets("gives Android's navigation bar the lock screen's colour and "
        'icons that read on it, and so does the privacy cover', (tester) async {
      await start(tester, settings: _immediately);

      await lockAgain(tester);
      final lockColour = Theme.of(tester.element(lockScreen))
          .colorScheme
          .surface;
      expect(SystemChrome.latestStyle?.systemNavigationBarColor, lockColour);
      expect(
        SystemChrome.latestStyle?.systemNavigationBarIconBrightness,
        Brightness.dark,
      );

      device.finish(DeviceAuthResult.success);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(privacyCover, findsOneWidget);
      expect(
        SystemChrome.latestStyle?.systemNavigationBarColor,
        AppTheme.brandScheme(Brightness.light).surface,
      );
      expect(
        SystemChrome.latestStyle?.systemNavigationBarIconBrightness,
        Brightness.dark,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    });

    testWidgets('keeps an unsaved page below and its state', (tester) async {
      await start(tester, settings: _immediately);
      expect(lockScreen, findsNothing);
      await pushPageBelow(tester);

      await lockAgain(tester);
      device.finish(DeviceAuthResult.success);
      await tester.pumpAndSettle();

      expect(lockScreen, findsNothing);
      expect(find.text(_belowTheLock), findsOneWidget);
    });

    testWidgets("hides the announcements' live region while locked; after "
        'the unlock it is back without the old message', (tester) async {
      useLiveRegionAnnouncements(tester);
      await start(tester, settings: _immediately);
      announce(tester.element(find.byType(Scaffold).first), 'Saved');
      await tester.pump();
      expect(announcerRegion(tester)?.label, 'Saved');

      await lockAgain(tester);
      expect(announcerRegion(tester), isNull);

      await tester.pump(AnnouncerHost.clearAfter);
      device.finish(DeviceAuthResult.success);
      await tester.pumpAndSettle();
      expect(announcerRegion(tester)?.label, '');
    });
  });

  group('system back while locked', () {
    testWidgets('the framework leaves back to the platform, so neither the '
        'back button nor the predictive back gesture reaches the routes; a '
        'pop that still arrives moves the app back and pops nothing', (
      tester,
    ) async {
      await start(tester, settings: _immediately);
      await pushPageBelow(tester);
      expect(backReports.last, isTrue);

      await lockAgain(tester);
      expect(backReports.last, isFalse);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text(_belowTheLock), findsOneWidget);
      expect(backgrounding.moves, 1);

      // A commit without a start, as from the back button on Android 14+,
      // falls back to the same pop.
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.backGesture.name,
        SystemChannels.backGesture.codec.encodeMethodCall(
          const MethodCall('commitBackGesture'),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(find.text(_belowTheLock), findsOneWidget);
      expect(backgrounding.moves, 2);

      // A navigation under the lock does not hand back to the framework.
      routerOf(tester).routerDelegate.navigatorKey.currentState!
          .push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
      await tester.pumpAndSettle();
      expect(backReports.last, isFalse);

      device.finish(DeviceAuthResult.success);
      await tester.pumpAndSettle();
      expect(backReports.last, isTrue);
    });

    testWidgets('the activity moves the app back on system back only while '
        'locked, also from a cold start', (tester) async {
      await start(tester, settings: _immediately);
      expect(backgrounding.backMovesToBack, [true, false]);

      await lockAgain(tester);
      expect(backgrounding.backMovesToBack.last, isTrue);

      device.finish(DeviceAuthResult.success);
      await tester.pumpAndSettle();
      expect(backgrounding.backMovesToBack.last, isFalse);
    });

    testWidgets('before Android 14, where back arrives as a pop and the '
        'platform would close the app, the framework keeps it while locked '
        'and moves the app back', (tester) async {
      auth.preferences.values[androidVersionKey] = '11';
      await start(tester, settings: _immediately);
      await pushPageBelow(tester);
      expect(backReports.last, isTrue);

      await lockAgain(tester);
      expect(backReports.last, isTrue);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text(_belowTheLock), findsOneWidget);
      expect(backgrounding.moves, 1);

      device.finish(DeviceAuthResult.success);
      await tester.pumpAndSettle();
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text(_belowTheLock), findsNothing);
      expect(backReports.last, isFalse);
    });

    testWidgets('on Android 14 the platform handles back while locked', (
      tester,
    ) async {
      auth.preferences.values[androidVersionKey] = '14';
      await start(tester, settings: _immediately);
      await pushPageBelow(tester);

      await lockAgain(tester);
      expect(backReports.last, isFalse);
    });

    testWidgets('after the unlock back pops the page again', (tester) async {
      await start(tester, settings: _immediately);
      await pushPageBelow(tester);
      await lockAgain(tester);
      device.finish(DeviceAuthResult.success);
      await tester.pumpAndSettle();

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();

      expect(find.text(_belowTheLock), findsNothing);
      expect(backgrounding.moves, 0);
    });

    testWidgets('the task pane beside the list waits under the lock with '
        'its tasks and draft; back while locked moves the app back and '
        'leaves it', (tester) async {
      useWindow(tester, androidTabletLandscape);
      data.tasks.all = [
        sampleTask(
          id: 7,
          title: 'Water the plants',
          relatedTasks: {
            TaskRelationKind.related: [sampleTask(id: 8, title: '')],
          },
        ),
        sampleTask(id: 8, title: 'Buy the pots'),
      ];
      data.details.detailsByTask[8] = const TaskDetails(
        maxPermission: Permission.write,
      );
      await start(tester, settings: _immediately);
      routerOf(tester).go(AppRoutes.project(1));
      await tester.pumpAndSettle();
      await tapTaskRow(tester, 7);
      await openRelatedInPane(tester);
      expect(paneTaskId(tester), 8);
      final composer = inPane(
        find.descendant(
          of: find.byType(CommentComposer),
          matching: find.byType(TextField),
        ),
      );
      await tester.enterText(composer, 'Half a thought');
      await tester.pump(const Duration(seconds: 1));
      expect(backReports.last, isTrue);

      await lockAgain(tester);
      expect(backReports.last, isFalse);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.backGesture.name,
        SystemChannels.backGesture.codec.encodeMethodCall(
          const MethodCall('commitBackGesture'),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(backgrounding.moves, 2);

      device.finish(DeviceAuthResult.success);
      await tester.pumpAndSettle();
      expect(lockScreen, findsNothing);
      expectPane(tester, taskId: 8);
      expect(
        inPane(find.byTooltip(en.taskDetailPaneBack('Water the plants'))),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(composer).controller!.text,
        'Half a thought',
      );
      expect(backReports.last, isTrue);
    });

    testWidgets('on the overview, where back would leave the app, the '
        'platform keeps it after the unlock', (tester) async {
      await start(tester, settings: _immediately);
      expect(backReports.last, isFalse);

      await lockAgain(tester);
      device.finish(DeviceAuthResult.success);
      await tester.pumpAndSettle();

      expect(backReports.last, isFalse);
    });
  });

  group('the privacy cover', () {
    testWidgets('shows while the app is inactive and the lock is on', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await start(tester);
      expect(lockScreen, findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(privacyCover, findsOneWidget);
      expect(announced(tester, en.tabAccount), isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(privacyCover, findsNothing);
      expect(announced(tester, en.tabAccount), isTrue);
      semantics.dispose();
    });

    testWidgets('not where the system hides Recents itself (Android 13+), '
        'so a tap while the app is inactive still reaches the page', (
      tester,
    ) async {
      await start(tester, recents: FakeRecentsScreenshots());
      containerOf(tester).listen(screenProtectionProvider, (_, _) {});
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(privacyCover, findsNothing);

      await tester.tap(find.text(en.tabAccount));
      await tester.pumpAndSettle();
      expect(routerOf(tester).state.matchedLocation, AppRoutes.account);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    testWidgets('not with the lock off', (tester) async {
      await start(tester, settings: const PrivacySettings());

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect(privacyCover, findsNothing);
    });

    testWidgets('not while the system prompt is up', (tester) async {
      await start(tester);
      device.holdPrompts = true;
      final turningOff = containerOf(tester)
          .read(appLockControllerProvider.notifier)
          .setAppLock(enabled: false, prompt: promptFor('off'));
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(privacyCover, findsNothing);

      device.finish(DeviceAuthResult.cancelled);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await turningOff;
      await tester.pumpAndSettle();
    });

    testWidgets('not during an excursion', (tester) async {
      await start(tester);
      final picker = Completer<void>();
      final excursion = containerOf(tester)
          .read(appExcursionsProvider)
          .run(() => picker.future);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(privacyCover, findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      picker.complete();
      await excursion;
      await tester.pumpAndSettle();
    });
  });

  group('while locked', () {
    testWidgets('a task link waits and opens after the unlock; the last '
        'request wins', (tester) async {
      await start(tester, settings: _immediately);
      await lockAgain(tester);

      await tester.binding.handlePushRoute('$oauthCallbackScheme://task/99');
      await tester.binding.handlePushRoute('$oauthCallbackScheme://task/7');
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailSheet), findsNothing);
      expect(data.resolver.resolved, isEmpty);

      device.finish(DeviceAuthResult.success);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(TaskDetailSheet),
          matching: find.text('Water the plants'),
        ),
        findsOneWidget,
      );
      expect(data.resolver.resolved, hasLength(1));
    });

    testWidgets('a link that comes before the app is back waits when the '
        'time out of sight has run out', (tester) async {
      await start(tester);
      expect(lockScreen, findsNothing);
      device.holdPrompts = true;

      await leave(tester);
      now = now.add(const Duration(minutes: 2));
      await tester.binding.handlePushRoute('$oauthCallbackScheme://task/7');
      await tester.pump();
      expect(lockState(tester).locked, isTrue);

      await comeBack(tester);
      expect(lockScreen, findsOneWidget);
      expect(find.byType(TaskDetailSheet), findsNothing);

      device.finish(DeviceAuthResult.success);
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailSheet), findsOneWidget);
    });

    testWidgets('a notification tap waits and opens after the unlock', (
      tester,
    ) async {
      await start(tester, settings: _immediately);
      await lockAgain(tester);
      final accountId = containerOf(tester)
          .read(accountsProvider)
          .value!
          .activeAccountId!;

      notifications.taps.tap(
        NotificationPayload(
          accountId: accountId,
          taskId: 7,
          key: '7:due',
        ).toJson(),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailSheet), findsNothing);

      device.finish(DeviceAuthResult.success);
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailSheet), findsOneWidget);
    });

    testWidgets('a share waits, stays with the platform, and opens after the '
        'unlock', (tester) async {
      await start(tester, settings: _immediately);
      await lockAgain(tester);

      data.shareSource.push(const IncomingShare(text: 'Buy milk'));
      await tester.pumpAndSettle();
      expect(find.byType(ShareSheet), findsNothing);
      expect(data.shareSource.calls, isNot(contains('clear')));

      device.finish(DeviceAuthResult.success);
      await tester.pumpAndSettle();

      expect(find.byType(ShareSheet), findsOneWidget);
    });
  });
}

final class _RecordingBackgrounding implements AppBackgrounding {
  int moves = 0;
  final backMovesToBack = <bool>[];

  @override
  Future<void> moveToBack() async => moves++;

  @override
  Future<void> setBackMovesToBack({required bool enabled}) async {
    backMovesToBack.add(enabled);
  }
}
