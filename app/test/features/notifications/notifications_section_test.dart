import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_os_ids.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/notifications/presentation/notifications_section.dart';

import '../../helpers/app_lock_fakes.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/guest_app.dart';
import '../../helpers/notification_ui_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

const granted = NotificationCapabilities(
  permission: NotificationPermission.granted,
  exactAlarms: true,
);

void main() {
  late AuthFakes auth;
  late NotificationFakes notifications;

  setUp(() {
    auth = AuthFakes();
    notifications = NotificationFakes(scheduledCount: 12);
  });

  String accountId(WidgetTester tester) =>
      containerOf(tester).read(accountsProvider).value!.activeAccountId!;

  Finder tabList() => find
      .descendant(
        of: find.byType(AccountTab),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> pumpSection(
    WidgetTester tester, {
    ServerConnection? server,
    String? accountTab,
  }) async {
    await auth.seedAccount(
      server ?? fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    await pumpVikunjaApp(tester, auth: auth, notifications: notifications);
    await openTab(tester, accountTab ?? en.tabAccount);
    await tester.scrollUntilVisible(
      find.byType(NotificationsSection),
      100,
      scrollable: tabList(),
    );
    await tester.pumpAndSettle();
  }

  Finder inSection(String text) => find.descendant(
    of: find.byType(NotificationsSection),
    matching: find.text(text),
  );

  Finder switchFor(String title) => find.ancestor(
    of: find.text(title),
    matching: find.byType(SwitchListTile),
  );

  bool switchValue(WidgetTester tester, String title) =>
      tester.widget<SwitchListTile>(switchFor(title)).value;

  testWidgets('shows both switches on, and how many are scheduled', (
    tester,
  ) async {
    await pumpSection(tester);

    expect(find.text(en.notificationsHeading), findsOneWidget);
    expect(switchValue(tester, en.notificationsReminders), isTrue);
    expect(switchValue(tester, en.notificationsDueDates), isTrue);
    expect(find.text(en.notificationsScheduledOnDevice(12)), findsOneWidget);
    expect(find.text(en.notificationsOff), findsNothing);
    expect(find.text(en.notificationsMayBeLate), findsNothing);
  });

  group('which tasks the switches notify about', () {
    testWidgets('on Vikunja 2.8.0 the tasks the user follows, in one '
        'sentence that says how to stop them, after the device mark alone', (
      tester,
    ) async {
      await pumpSection(tester, server: fullServer280());

      expect(inSection(en.notificationsFollowedTasksNote), findsOneWidget);
      expect(find.text(en.notificationsForOwnTasks), findsNothing);
      expect(
        RegExp('[.;] [A-Z]').hasMatch(en.notificationsFollowedTasksNote),
        isFalse,
      );
      expect(en.notificationsFollowedTasksNote, contains('unfollow a task'));
      final header = find.ancestor(
        of: find.text(en.notificationsHeading),
        matching: find.byType(ListSectionHeader),
      );
      expect(
        find.descendant(
          of: header,
          matching: find.text(en.onThisDeviceHeading),
        ),
        findsOneWidget,
      );
      final texts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(NotificationsSection),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data)
          .toList();
      expect(
        texts.indexOf(en.notificationsFollowedTasksNote),
        texts.indexOf(en.onThisDeviceHeading) + 1,
      );
    });

    testWidgets('on an older server the tasks the user created or is '
        'assigned to', (tester) async {
      await pumpSection(tester);

      expect(inSection(en.notificationsForOwnTasks), findsOneWidget);
      expect(find.text(en.notificationsFollowedTasksNote), findsNothing);
    });

    testWidgets('a guest through a shared link is told neither', (
      tester,
    ) async {
      await pumpGuestApp(
        tester,
        auth: auth,
        data: SyncFakes(),
        connection: fullServer280(),
      );
      await openTab(tester, en.tabAccount);
      await tester.scrollUntilVisible(
        switchFor(en.notificationsDueDates),
        100,
        scrollable: tabList(),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.notificationsFollowedTasksNote), findsNothing);
      expect(find.text(en.notificationsForOwnTasks), findsNothing);
      expect(
        find.descendant(
          of: find.byType(NotificationsSection),
          matching: find.text(en.onThisDeviceHeading),
        ),
        findsOneWidget,
      );
    });

    testWidgets('at 200 % text the line wraps without an overflow', (
      tester,
    ) async {
      usePhoneSurface(tester, logicalSize: const Size(320, 640));
      useAccessibilityExtremes(tester);
      await pumpSection(tester, server: fullServer280());
      await tester.scrollUntilVisible(
        inSection(en.notificationsFollowedTasksNote),
        100,
        scrollable: tabList(),
      );
      await tester.pumpAndSettle();

      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: inSection(en.notificationsFollowedTasksNote),
          matching: find.byType(RichText),
        ),
      );
      expect(
        paragraph.getMaxIntrinsicWidth(double.infinity),
        greaterThan(paragraph.size.width),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.debugHasOverflowShader, isFalse);
      expect(
        paragraph.size.height,
        greaterThanOrEqualTo(paragraph.textSize.height),
      );
      expect(
        tester.getRect(inSection(en.notificationsFollowedTasksNote)).right,
        lessThanOrEqualTo(320),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('in German', (tester) async {
      useLocale(tester, const Locale('de'));
      await pumpSection(
        tester,
        server: fullServer280(),
        accountTab: de.tabAccount,
      );

      expect(inSection(de.notificationsFollowedTasksNote), findsOneWidget);
    });
  });

  testWidgets('a switch writes the account preference', (tester) async {
    await pumpSection(tester);

    await tester.tap(switchFor(en.notificationsReminders));
    await tester.pumpAndSettle();

    expect(
      notifications.preferences.values[accountId(tester)],
      const NotificationPreferences(reminders: false),
    );
    expect(switchValue(tester, en.notificationsReminders), isFalse);
    expect(switchValue(tester, en.notificationsDueDates), isTrue);

    await tester.tap(switchFor(en.notificationsDueDates));
    await tester.pumpAndSettle();

    expect(
      notifications.preferences.values[accountId(tester)],
      const NotificationPreferences(reminders: false, dueDates: false),
    );
  });

  testWidgets('the activity switch is on and writes the account preference '
      'alone', (tester) async {
    await pumpSection(tester);
    await tester.scrollUntilVisible(
      switchFor(en.notificationsActivity),
      100,
      scrollable: find
          .descendant(
            of: find.byType(AccountTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text(en.notificationsActivitySubtitle), findsOneWidget);
    expect(switchValue(tester, en.notificationsActivity), isTrue);

    await tester.tap(switchFor(en.notificationsActivity));
    await tester.pumpAndSettle();

    expect(
      notifications.preferences.values[accountId(tester)],
      const NotificationPreferences(activity: false),
    );
    expect(switchValue(tester, en.notificationsActivity), isFalse);
    expect(switchValue(tester, en.notificationsReminders), isTrue);
  });

  testWidgets('shows the stored preferences', (tester) async {
    await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    final entry = (await auth.registry.load()).activeAccount!;
    notifications.preferences.values[entry.id] = const NotificationPreferences(
      dueDates: false,
      activity: false,
    );
    await pumpSection(tester);

    expect(switchValue(tester, en.notificationsReminders), isTrue);
    expect(switchValue(tester, en.notificationsDueDates), isFalse);
    expect(switchValue(tester, en.notificationsActivity), isFalse);
  });

  testWidgets('nothing scheduled', (tester) async {
    notifications.scheduledCount = 0;
    await pumpSection(tester);

    expect(find.text(en.notificationsScheduledOnDevice(0)), findsOneWidget);
  });

  testWidgets('denied at the OS level: off, with the settings', (tester) async {
    notifications.gateway.current = const NotificationCapabilities(
      permission: NotificationPermission.denied,
      exactAlarms: false,
    );
    await pumpSection(tester);

    expect(find.text(en.notificationsOff), findsOneWidget);
    expect(find.text(en.notificationsMayBeLate), findsNothing);

    await tester.tap(find.text(en.notificationsOpenSettings));
    await tester.pumpAndSettle();
    expect(notifications.calls('openNotificationSettings'), 1);

    final testRow = tester.widget<ListTile>(
      find.widgetWithText(ListTile, en.notificationsSendTest),
    );
    expect(testRow.enabled, isFalse);
  });

  testWidgets('never asked: off, with a request', (tester) async {
    notifications.gateway.current = const NotificationCapabilities(
      permission: NotificationPermission.notAsked,
      exactAlarms: false,
    );
    notifications.answerRequestWith(granted);
    await pumpSection(tester);

    expect(find.text(en.notificationsOff), findsOneWidget);

    await tester.tap(find.text(en.notificationsTurnOn));
    await tester.pumpAndSettle();

    expect(notifications.calls('requestPermission'), 1);
    expect(find.text(en.notificationsOff), findsNothing);
  });

  testWidgets('without exact alarms: may be late, with the setting', (
    tester,
  ) async {
    notifications.gateway.current = const NotificationCapabilities(
      permission: NotificationPermission.granted,
      exactAlarms: false,
    );
    await pumpSection(tester);

    expect(find.text(en.notificationsMayBeLate), findsOneWidget);
    expect(find.text(en.notificationsOff), findsNothing);

    await tester.tap(find.text(en.notificationsAllowExactAlarms));
    await tester.pumpAndSettle();
    expect(notifications.calls('openExactAlarmSettings'), 1);
  });

  testWidgets('the Reminders channel off in the system settings: off, with '
      'the settings, and no test notification, which would not show', (
    tester,
  ) async {
    notifications.gateway.current = const NotificationCapabilities(
      permission: NotificationPermission.granted,
      exactAlarms: false,
      remindersChannelOff: true,
    );
    await pumpSection(tester);

    expect(inSection(en.notificationsRemindersChannelOff), findsOneWidget);
    expect(find.text(en.notificationsOff), findsNothing);
    expect(find.text(en.notificationsMayBeLate), findsNothing);
    final testRow = tester.widget<ListTile>(
      find.widgetWithText(ListTile, en.notificationsSendTest),
    );
    expect(testRow.enabled, isFalse);

    await tester.tap(find.text(en.notificationsOpenSettings));
    await tester.pumpAndSettle();
    expect(notifications.calls('openNotificationSettings'), 1);
  });

  testWidgets('re-reads what the OS allows when the app resumes', (
    tester,
  ) async {
    notifications.gateway.current = const NotificationCapabilities(
      permission: NotificationPermission.denied,
      exactAlarms: false,
    );
    await pumpSection(tester);
    expect(find.text(en.notificationsOff), findsOneWidget);

    notifications.gateway.current = granted;
    [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);
    await tester.pumpAndSettle();

    expect(find.text(en.notificationsOff), findsNothing);
  });

  testWidgets('a read that fails on resume keeps the previous answer', (
    tester,
  ) async {
    await pumpSection(tester);
    expect(find.text(en.notificationsOff), findsNothing);
    notifications.gateway.beforeCall = (call) async {
      if (call == 'capabilities') throw StateError('channel');
    };

    [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);
    await tester.pumpAndSettle();

    expect(find.text(en.notificationsOff), findsNothing);
    expect(find.text(en.notificationsScheduledOnDevice(12)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sends a test notification for this account', (tester) async {
    await pumpSection(tester);

    await tester.tap(find.text(en.notificationsSendTest));
    await tester.pumpAndSettle();

    expect(notifications.gateway.shown, hasLength(1));
    final shown = notifications.gateway.shown.single;
    expect(shown.osId, NotificationOsIds.testNotification);
    expect(shown.title, en.notificationTestTitle);
    expect(shown.body, en.notificationTestBody);
    final payload = NotificationPayload.fromJson(shown.payload);
    expect(payload.accountId, accountId(tester));
    expect(payload.taskId, testNotificationTaskId);
    expect(shown.privacy, const NotificationPrivacy());
  });

  testWidgets('with "hide on the lock screen" the test notification stays '
      'off the lock screen like a reminder', (tester) async {
    await storePrivacySettings(
      auth.preferences,
      const PrivacySettings(
        notificationContent: NotificationContent.hiddenOnLockScreen,
      ),
    );
    await pumpSection(tester);

    await tester.tap(find.text(en.notificationsSendTest));
    await tester.pumpAndSettle();

    final shown = notifications.gateway.shown.single;
    expect(shown.privacy.hiddenOnLockScreen, isTrue);
    expect(shown.osId, NotificationOsIds.testNotification);
  });

  testWidgets('in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    await pumpVikunjaApp(tester, auth: auth, notifications: notifications);
    await openTab(tester, de.tabAccount);
    await tester.scrollUntilVisible(
      find.byType(NotificationsSection),
      100,
      scrollable: find
          .descendant(
            of: find.byType(AccountTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.text(de.notificationsHeading), findsOneWidget);
    expect(find.text(de.notificationsForOwnTasks), findsOneWidget);
    expect(find.text(de.notificationsReminders), findsOneWidget);
    expect(find.text(de.notificationsScheduledOnDevice(12)), findsOneWidget);
  });
}
