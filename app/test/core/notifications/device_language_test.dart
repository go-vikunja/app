import 'dart:ui' show Locale;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/activity/activity_providers.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/security/app_lock_controller.dart';
import 'package:vikunja_mobile/core/security/device_authenticator.dart';
import 'package:vikunja_mobile/core/security/privacy_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

import '../../helpers/app_lock_fakes.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/unshipped_language.dart';
import '../../helpers/widget_fakes.dart';

const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
final AppLocalizations de = lookupAppLocalizations(const Locale('de'));

// The app's container as bootstrap builds it, with the notification plugin
// on a mocked channel, a fake widget host and a fake device prompt; the
// test binding's locales stand for the device or per-app language.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const alice = User(id: 7, username: 'alice');
  final now = DateTime(2026, 10, 26, 9);
  late List<MethodCall> calls;
  late Map<int, Map<String, Object?>> pending;
  late AuthFakes auth;
  late FakeWidgetHost host;
  late FakeDeviceAuthenticator authenticator;
  late ProviderContainer container;

  ProviderContainer newContainer(AppLocalizations started) {
    final files = FakeAccountDatabaseFiles();
    return ProviderContainer(
      overrides: [
        ...auth.overrides,
        accountDatabaseFilesProvider.overrideWithValue(files),
        openDatabasesProvider.overrideWithValue(
          OpenDatabases(
            files,
            open: (_, _) => AppDatabase(NativeDatabase.memory()),
          ),
        ),
        clockProvider.overrideWithValue(() => now),
        widgetHostProvider.overrideWithValue(host),
        runsHeadlessProvider.overrideWithValue(false),
        deviceAuthenticatorProvider.overrideWithValue(authenticator),
        deviceAppLocalizationsProvider.overrideWithBuild((_, _) => started),
      ],
    );
  }

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    calls = [];
    pending = {};
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
      call,
    ) async {
      calls.add(call);
      final arguments = call.arguments is Map
          ? Map<String, Object?>.from(call.arguments as Map)
          : const <String, Object?>{};
      switch (call.method) {
        case 'initialize' ||
            'areNotificationsEnabled' ||
            'canScheduleExactNotifications':
          return true;
        case 'zonedSchedule':
          pending[arguments['id']! as int] = arguments;
        case 'cancel':
          pending.remove(arguments['id']);
        case 'pendingNotificationRequests':
          return [
            for (final MapEntry(:key, :value) in pending.entries)
              {
                'id': key,
                'title': value['title'],
                'body': value['body'],
                'payload': value['payload'],
              },
          ];
        case 'getActiveNotifications':
          return <Object?>[];
      }
      return null;
    });
    auth = AuthFakes();
    host = FakeWidgetHost();
    authenticator = FakeDeviceAuthenticator(result: DeviceAuthResult.cancelled);
  });

  tearDown(() {
    container.dispose();
    binding.platformDispatcher.clearLocalesTestValue();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
    debugDefaultTargetPlatformOverride = null;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
  });

  /// Alice signed in with a task due in 2036 (the plugin refuses an
  /// instant before the real clock), her scheduler and a Today widget,
  /// the app lock on, everything settled in [started].
  Future<Account> started(AppLocalizations started) async {
    await storePrivacySettings(
      auth.preferences,
      const PrivacySettings(appLock: true),
    );
    container = newContainer(started);
    final entry = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now, userId: alice.id),
    );
    await container.read(accountsProvider.future);
    final db = container.read(appDatabaseProvider(entry.id));
    await db.projectsDao.upsertAll([sampleProject(id: 7, title: 'Work')]);
    await db.tasksDao.upsertAll([
      sampleTask(
        id: 1,
        title: 'Water the plants',
        projectId: 7,
        due: DateTime.utc(2036, 10, 13, 8, 30),
      ).copyWith(createdBy: alice),
    ], syncRunId: 'run');
    host.placed[1] = WidgetConfig(accountId: entry.id, kind: const TodayKind());
    await container.read(privacySettingsControllerProvider.future);
    container
      ..listen(deviceLanguageFollowerProvider, (_, _) {})
      ..listen(appLockControllerProvider, (_, _) {})
      ..listen(accountNotificationSchedulersProvider, (_, _) {})
      ..listen(accountWidgetPublishersProvider, (_, _) {});
    await pumpEventQueue();
    return entry.account;
  }

  Map<String, Object?> argumentsOf(MethodCall call) =>
      Map<String, Object?>.from(call.arguments as Map);

  Map<String, Object?> specificsOf(MethodCall call) =>
      Map<String, Object?>.from(argumentsOf(call)['platformSpecifics']! as Map);

  List<MethodCall> callsOf(String method) => [
    for (final call in calls)
      if (call.method == method) call,
  ];

  List<String?> actionTitles(MethodCall call) => [
    for (final action in specificsOf(call)['actions']! as List)
      (action as Map)['title'] as String?,
  ];

  String todayTitle(Account account) =>
      host.snapshot('${account.id}.today')!.title;

  test('switching from English to German while the app runs renames the '
      'channels, schedules everything again, republishes the widgets and '
      'words the activity notifications and the lock prompt in German, '
      'noting "de" for the headless isolates', () async {
    final account = await started(en);
    expect(callsOf('zonedSchedule'), hasLength(1));
    expect(actionTitles(callsOf('zonedSchedule').single), [
      en.notificationActionDone,
      en.notificationActionSnooze10Minutes,
      en.notificationActionSnooze1Hour,
    ]);
    expect(
      argumentsOf(callsOf('zonedSchedule').single)['body'],
      en.notificationDueBody('Work'),
    );
    expect(todayTitle(account), en.sectionToday);
    calls.clear();

    binding.platformDispatcher.localesTestValue = const [Locale('de', 'DE')];
    await pumpEventQueue();

    expect(container.read(deviceAppLocalizationsProvider).localeName, 'de');
    expect(auth.preferences.values[notificationLocaleKey], 'de');
    final channels = {
      for (final call in callsOf('createNotificationChannel'))
        argumentsOf(call)['id']: argumentsOf(call),
    };
    expect(channels.keys, {
      LocalNotificationGateway.channelId,
      LocalNotificationGateway.activityChannelId,
    });
    final reminders = channels[LocalNotificationGateway.channelId]!;
    expect(reminders['name'], de.notificationChannelReminders);
    expect(
      reminders['description'],
      de.notificationChannelRemindersDescription,
    );
    final activity = channels[LocalNotificationGateway.activityChannelId]!;
    expect(activity['name'], de.notificationChannelActivity);
    expect(activity['description'], de.notificationChannelActivityDescription);

    final scheduled = callsOf('zonedSchedule').single;
    final id = argumentsOf(scheduled)['id'];
    expect(
      calls.indexWhere(
        (call) => call.method == 'cancel' && argumentsOf(call)['id'] == id,
      ),
      lessThan(calls.indexOf(scheduled)),
      reason: 'a forced run cancels and schedules again',
    );
    expect(argumentsOf(scheduled)['body'], de.notificationDueBody('Work'));
    expect(
      specificsOf(scheduled)['channelName'],
      de.notificationChannelReminders,
    );
    expect(actionTitles(scheduled), [
      de.notificationActionDone,
      de.notificationActionSnooze10Minutes,
      de.notificationActionSnooze1Hour,
    ]);

    expect(todayTitle(account), de.sectionToday);

    await container.read(activityNoticesProvider).sessionEnded(account);
    final shown = argumentsOf(callsOf('show').single);
    expect(
      shown['title'],
      de.sessionEndedNotificationTitle('tasks.example.org'),
    );
    expect(shown['body'], de.sessionEndedNotificationBody('alice'));
    expect(
      specificsOf(callsOf('show').single)['channelName'],
      de.notificationChannelActivity,
    );

    expect(container.read(appLockControllerProvider).locked, isTrue);
    await container.read(appLockControllerProvider.notifier).unlock();
    expect(authenticator.reasons, [de.appLockPromptReason]);
    expect(authenticator.promptTexts.single.hint, de.appLockPromptHint);
    expect(authenticator.promptTexts.single.cancel, de.cancel);
  });

  test('a language set before the app listens is followed once it '
      'listens', () async {
    binding.platformDispatcher.localesTestValue = const [Locale('de', 'DE')];

    final account = await started(en);

    expect(container.read(deviceAppLocalizationsProvider).localeName, 'de');
    expect(auth.preferences.values[notificationLocaleKey], 'de');
    final reminders = callsOf('createNotificationChannel')
        .map(argumentsOf)
        .lastWhere(
          (channel) => channel['id'] == LocalNotificationGateway.channelId,
        );
    expect(reminders['name'], de.notificationChannelReminders);
    expect(todayTitle(account), de.sectionToday);
  });

  test('a language the app has no strings for falls back to English', () async {
    binding.platformDispatcher.localesTestValue = const [Locale('de', 'DE')];
    final account = await started(de);
    calls.clear();

    binding.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
    await pumpEventQueue();

    expect(container.read(deviceAppLocalizationsProvider).localeName, 'en');
    expect(auth.preferences.values[notificationLocaleKey], 'en');
    expect(
      argumentsOf(callsOf('createNotificationChannel').first)['name'],
      en.notificationChannelReminders,
    );
    expect(todayTitle(account), en.sectionToday);
  });

  final unshipped = unshippedLanguageWithArb();

  test('a language with an ARB file that the app does not ship falls back '
      'to English for the notifications, the widgets and the lock '
      'prompt', () async {
    binding.platformDispatcher.localesTestValue = const [Locale('de', 'DE')];
    final account = await started(de);
    calls.clear();

    binding.platformDispatcher.localesTestValue = [unshipped!];
    await pumpEventQueue();

    expect(container.read(deviceAppLocalizationsProvider).localeName, 'en');
    expect(auth.preferences.values[notificationLocaleKey], 'en');
    expect(
      argumentsOf(callsOf('createNotificationChannel').first)['name'],
      en.notificationChannelReminders,
    );
    expect(todayTitle(account), en.sectionToday);
    expect(container.read(appLockControllerProvider).locked, isTrue);
    await container.read(appLockControllerProvider.notifier).unlock();
    expect(authenticator.reasons, [en.appLockPromptReason]);
  }, skip: unshipped == null ? 'every language with an ARB file ships' : null);

  test('a resume in the same language changes nothing; one after a change '
      'that went unreported follows it', () async {
    await started(en);
    auth.preferences.values.remove(notificationLocaleKey);
    calls.clear();
    final writes = host.calls.length;

    binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpEventQueue();

    expect(container.read(deviceAppLocalizationsProvider).localeName, 'en');
    expect(auth.preferences.values.containsKey(notificationLocaleKey), isFalse);
    expect(callsOf('createNotificationChannel'), isEmpty);
    expect(callsOf('zonedSchedule'), isEmpty);
    expect(
      host.calls.skip(writes).where((c) => c.startsWith('writeSnapshot')),
      isEmpty,
    );

    // Set without telling the binding's observers.
    final onLocaleChanged = binding.platformDispatcher.onLocaleChanged;
    addTearDown(
      () => binding.platformDispatcher.onLocaleChanged = onLocaleChanged,
    );
    binding.platformDispatcher
      ..onLocaleChanged = null
      ..localesTestValue = const [Locale('de')];
    binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpEventQueue();

    expect(container.read(deviceAppLocalizationsProvider).localeName, 'de');
    expect(auth.preferences.values[notificationLocaleKey], 'de');
    expect(
      argumentsOf(callsOf('createNotificationChannel').first)['name'],
      de.notificationChannelReminders,
    );
  });
}
