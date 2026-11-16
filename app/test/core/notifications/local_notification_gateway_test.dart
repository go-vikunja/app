import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

import '../../helpers/unshipped_language.dart';

const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
final AppLocalizations de = lookupAppLocalizations(const Locale('de'));

@pragma('vm:entry-point')
void _backgroundEntryPoint(NotificationResponse response) {}

final class _MemoryPreferences implements PreferencesStore {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 12, 20);
  late List<MethodCall> calls;
  late Map<String, Object?> answers;
  late Exception? Function(MethodCall call)? throwing;
  late _MemoryPreferences preferences;
  late List<NotificationResponse> responses;

  setUp(() {
    calls = [];
    // The Android initialise answers whether it succeeded.
    answers = {'initialize': true};
    throwing = null;
    preferences = _MemoryPreferences();
    responses = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          final error = throwing?.call(call);
          if (error != null) throw error;
          return answers[call.method];
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  LocalNotificationGateway gateway({
    TargetPlatform platform = TargetPlatform.android,
    bool background = true,
  }) {
    debugDefaultTargetPlatformOverride = platform;
    switch (platform) {
      case TargetPlatform.iOS:
        IOSFlutterLocalNotificationsPlugin.registerWith();
      case _:
        AndroidFlutterLocalNotificationsPlugin.registerWith();
    }
    return LocalNotificationGateway(
      texts: localNotificationTexts(en),
      preferences: preferences,
      onResponse: responses.add,
      onBackgroundResponse: background ? _backgroundEntryPoint : null,
      clock: () => now,
    );
  }

  MethodCall call(String method) =>
      calls.singleWhere((call) => call.method == method);

  Map<String, Object?> args(MethodCall call) =>
      Map<String, Object?>.from(call.arguments as Map);

  Map<String, Object?> platformSpecifics(MethodCall call) =>
      Map<String, Object?>.from(args(call)['platformSpecifics']! as Map);

  // The plugin refuses an instant before the real clock, so the fixture
  // lies well ahead of any test run.
  final notification = ScheduledNotification(
    osId: 77,
    fireAt: DateTime.utc(2036, 10, 13, 8, 30),
    title: 'Water the plants',
    body: 'Reminder · Home',
    payload: '{"account":"a","task":5,"key":"5:due"}',
    exact: true,
  );

  group('initialize', () {
    test('Android: the icon, both callbacks, then the channel', () async {
      final gateway0 = gateway();
      await gateway0.initialize();
      await gateway0.initialize();
      await gateway0.cancel(1);

      expect(calls.map((c) => c.method), [
        'initialize',
        'createNotificationChannel',
        'createNotificationChannel',
        'cancel',
      ]);
      final init = args(call('initialize'));
      expect(init['defaultIcon'], LocalNotificationGateway.androidIcon);
      expect(init['dispatcher_handle'], isA<int>());
      expect(init['callback_handle'], isA<int>());
      final channels = [
        for (final call in calls)
          if (call.method == 'createNotificationChannel') args(call),
      ];
      final channel = channels.first;
      expect(channel['id'], LocalNotificationGateway.channelId);
      expect(channel['name'], en.notificationChannelReminders);
      expect(
        channel['description'],
        en.notificationChannelRemindersDescription,
      );
      expect(channel['importance'], Importance.high.value);
      final activity = channels.last;
      expect(activity['id'], LocalNotificationGateway.activityChannelId);
      expect(activity['name'], en.notificationChannelActivity);
      expect(
        activity['description'],
        en.notificationChannelActivityDescription,
      );
      expect(activity['importance'], Importance.defaultImportance.value);
    });

    test('iOS: both task categories with background actions, no '
        'prompt; the locked one asks for the device unlock for Done '
        'only', () async {
      // Implied by the first use.
      await gateway(platform: TargetPlatform.iOS).cancel(1);

      expect(calls.map((c) => c.method), ['initialize', 'cancel']);
      final init = args(call('initialize'));
      expect(init['requestAlertPermission'], isFalse);
      expect(init['requestBadgePermission'], isFalse);
      expect(init['requestSoundPermission'], isFalse);
      final categories = [
        for (final category in init['notificationCategories']! as List)
          Map<String, Object?>.from(category as Map),
      ];
      expect(categories.map((c) => c['identifier']), [
        LocalNotificationGateway.darwinCategoryId,
        LocalNotificationGateway.darwinLockedCategoryId,
      ]);
      List<Map<String, Object?>> actionsOf(Map<String, Object?> category) =>
          (category['actions']! as List)
              .map((a) => Map<String, Object?>.from(a as Map))
              .toList();
      for (final category in categories) {
        final actions = actionsOf(category);
        expect(actions.map((a) => a['identifier']), [
          NotificationActionIds.markDone,
          NotificationActionIds.snooze10Minutes,
          NotificationActionIds.snooze1Hour,
        ]);
        expect(actions.map((a) => a['title']), [
          en.notificationActionDone,
          en.notificationActionSnooze10Minutes,
          en.notificationActionSnooze1Hour,
        ]);
        for (final action in actions) {
          expect(action['type'], 'plain');
        }
      }
      for (final action in actionsOf(categories.first)) {
        expect(action['options'], isEmpty, reason: 'no foreground option');
      }
      expect(actionsOf(categories.last).map((a) => a['options']), [
        [DarwinNotificationActionOption.authenticationRequired.value],
        isEmpty,
        isEmpty,
      ]);
    });

    test('without a background entry point', () async {
      await gateway(background: false).initialize();

      final init = args(call('initialize'));
      expect(init.containsKey('callback_handle'), isFalse);
    });
  });

  group('updateTexts', () {
    List<Map<String, Object?>> channels() => [
      for (final call in calls)
        if (call.method == 'createNotificationChannel') args(call),
    ];

    test('Android, once initialised: both channels again under their ids '
        'with the new names; what is scheduled later has the new action '
        'titles', () async {
      final gateway0 = gateway();
      await gateway0.initialize();
      calls.clear();

      await gateway0.updateTexts(localNotificationTexts(de));

      expect(calls.map((c) => c.method), [
        'createNotificationChannel',
        'createNotificationChannel',
      ]);
      expect(channels().map((c) => c['id']), [
        LocalNotificationGateway.channelId,
        LocalNotificationGateway.activityChannelId,
      ]);
      expect(channels().map((c) => c['name']), [
        de.notificationChannelReminders,
        de.notificationChannelActivity,
      ]);
      expect(channels().map((c) => c['description']), [
        de.notificationChannelRemindersDescription,
        de.notificationChannelActivityDescription,
      ]);
      expect(channels().first['importance'], Importance.high.value);

      await gateway0.schedule(notification);
      final specifics = platformSpecifics(call('zonedSchedule'));
      expect(specifics['channelName'], de.notificationChannelReminders);
      expect(
        [
          for (final action in specifics['actions']! as List)
            (action as Map)['title'],
        ],
        [
          de.notificationActionDone,
          de.notificationActionSnooze10Minutes,
          de.notificationActionSnooze1Hour,
        ],
      );
    });

    test('before the plugin is initialised nothing is called; the first '
        'use creates the channels with the new names', () async {
      final gateway0 = gateway();

      await gateway0.updateTexts(localNotificationTexts(de));
      expect(calls, isEmpty);

      await gateway0.cancel(1);
      expect(channels().map((c) => c['name']), [
        de.notificationChannelReminders,
        de.notificationChannelActivity,
      ]);
    });

    test('a channel the plugin refuses is logged, not thrown', () async {
      final gateway0 = gateway();
      await gateway0.initialize();
      throwing = (call) => call.method == 'createNotificationChannel'
          ? PlatformException(code: 'error')
          : null;

      await expectLater(
        gateway0.updateTexts(localNotificationTexts(de)),
        completes,
      );
    });

    test('iOS: nothing is called, since the app restarts for a new '
        'language', () async {
      final gateway0 = gateway(platform: TargetPlatform.iOS);
      await gateway0.initialize();
      calls.clear();

      await gateway0.updateTexts(localNotificationTexts(de));

      expect(calls, isEmpty);
    });
  });

  group('schedule', () {
    test('an exact alarm at the UTC instant with the actions', () async {
      await gateway().schedule(notification);

      final scheduled = args(call('zonedSchedule'));
      expect(scheduled['id'], 77);
      expect(scheduled['title'], notification.title);
      expect(scheduled['body'], notification.body);
      expect(scheduled['payload'], notification.payload);
      expect(scheduled['timeZoneName'], 'Etc/UTC');
      expect(scheduled['scheduledDateTime'], '2036-10-13T08:30:00');
      final specifics = platformSpecifics(call('zonedSchedule'));
      expect(specifics['scheduleMode'], 'exactAllowWhileIdle');
      expect(specifics['channelId'], LocalNotificationGateway.channelId);
      expect(specifics['channelName'], en.notificationChannelReminders);
      expect(specifics['importance'], Importance.high.value);
      expect(specifics['priority'], Priority.high.value);
      expect(specifics['category'], 'reminder');
      final actions = (specifics['actions']! as List)
          .map((a) => Map<String, Object?>.from(a as Map))
          .toList();
      expect(actions.map((a) => a['id']), [
        NotificationActionIds.markDone,
        NotificationActionIds.snooze10Minutes,
        NotificationActionIds.snooze1Hour,
      ]);
      expect(actions.map((a) => a['title']), [
        en.notificationActionDone,
        en.notificationActionSnooze10Minutes,
        en.notificationActionSnooze1Hour,
      ]);
      for (final action in actions) {
        expect(action['showsUserInterface'], isFalse);
        expect(action['cancelNotification'], isTrue);
      }
      expect(specifics['visibility'], isNull);
    });

    test('hidden on the lock screen: secret, not private, which would '
        'still show the title', () async {
      await gateway().schedule(
        ScheduledNotification(
          osId: 1,
          fireAt: notification.fireAt,
          title: 't',
          body: 'b',
          payload: 'p',
          exact: true,
          privacy: const NotificationPrivacy(hiddenOnLockScreen: true),
        ),
      );

      expect(
        platformSpecifics(call('zonedSchedule'))['visibility'],
        NotificationVisibility.secret.index,
      );
    });

    test('inexact when exact alarms are not allowed', () async {
      await gateway().schedule(
        ScheduledNotification(
          osId: 1,
          fireAt: notification.fireAt,
          title: 't',
          body: 'b',
          payload: 'p',
          exact: false,
        ),
      );

      expect(
        platformSpecifics(call('zonedSchedule'))['scheduleMode'],
        'inexactAllowWhileIdle',
      );
    });

    test('iOS: the task category, shown in the foreground too', () async {
      await gateway(platform: TargetPlatform.iOS).schedule(notification);

      final scheduled = args(call('zonedSchedule'));
      expect(scheduled['timeZoneName'], 'Etc/UTC');
      expect(scheduled['scheduledDateTime'], '2036-10-13T08:30:00');
      final specifics = platformSpecifics(call('zonedSchedule'));
      expect(
        specifics['categoryIdentifier'],
        LocalNotificationGateway.darwinCategoryId,
      );
      expect(specifics['presentAlert'], isTrue);
      expect(specifics['presentBanner'], isTrue);
      expect(specifics['presentList'], isTrue);
    });

    test('iOS: the locked category while Done needs the device '
        'unlocked, also when shown at once', () async {
      const locked = NotificationPrivacy(doneNeedsUnlock: true);
      final gateway0 = gateway(platform: TargetPlatform.iOS);
      await gateway0.schedule(
        ScheduledNotification(
          osId: 1,
          fireAt: notification.fireAt,
          title: 't',
          body: 'b',
          payload: 'p',
          exact: true,
          privacy: locked,
        ),
      );
      await gateway0.schedule(
        ScheduledNotification(
          osId: 2,
          fireAt: now,
          title: 't',
          body: 'b',
          payload: 'p',
          exact: true,
          privacy: locked,
        ),
      );

      expect(
        platformSpecifics(call('zonedSchedule'))['categoryIdentifier'],
        LocalNotificationGateway.darwinLockedCategoryId,
      );
      expect(
        platformSpecifics(call('show'))['categoryIdentifier'],
        LocalNotificationGateway.darwinLockedCategoryId,
      );
    });

    test('an instant due within a second is shown at once', () async {
      await gateway().schedule(
        ScheduledNotification(
          osId: 3,
          fireAt: now.add(const Duration(milliseconds: 900)),
          title: 't',
          body: 'b',
          payload: 'p',
          exact: true,
        ),
      );

      expect(calls.map((c) => c.method), isNot(contains('zonedSchedule')));
      final shown = args(call('show'));
      expect(shown['id'], 3);
      expect(shown['payload'], 'p');
      expect(platformSpecifics(call('show'))['actions'], hasLength(3));
    });

    test('a refused exact alarm is scheduled inexactly', () async {
      throwing = (call) =>
          call.method == 'zonedSchedule' &&
              platformSpecifics(call)['scheduleMode'] == 'exactAllowWhileIdle'
          ? PlatformException(code: 'exact_alarms_not_permitted')
          : null;

      await gateway().schedule(notification);

      expect(
        calls
            .where((c) => c.method == 'zonedSchedule')
            .map((c) => platformSpecifics(c)['scheduleMode']),
        ['exactAllowWhileIdle', 'inexactAllowWhileIdle'],
      );
    });

    test('any other failure propagates', () async {
      throwing = (call) => call.method == 'zonedSchedule'
          ? PlatformException(code: 'boom')
          : null;

      await expectLater(
        gateway().schedule(
          ScheduledNotification(
            osId: 1,
            fireAt: notification.fireAt,
            title: 't',
            body: 'b',
            payload: 'p',
            exact: false,
          ),
        ),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  test('cancel, pendingIds and showNow', () async {
    answers['pendingNotificationRequests'] = [
      {'id': 4, 'title': 't', 'body': 'b', 'payload': 'p'},
      {'id': 9, 'title': 't', 'body': 'b', 'payload': 'p'},
    ];
    final gateway0 = gateway();

    await gateway0.cancel(4);
    expect(await gateway0.pendingIds(), {4, 9});
    await gateway0.showNow(osId: 1, title: 'Test', body: 'Body', payload: 'p');

    expect(args(call('cancel'))['id'], 4);
    final shown = args(call('show'));
    expect(shown['id'], 1);
    expect(shown['title'], 'Test');
    expect(shown['body'], 'Body');
    expect(shown['payload'], 'p');
    expect(
      platformSpecifics(call('show'))['channelId'],
      LocalNotificationGateway.channelId,
    );
  });

  test('showNow follows the privacy it is given', () async {
    await gateway().showNow(
      osId: 1,
      title: 'Test',
      body: 'Body',
      payload: 'p',
      privacy: const NotificationPrivacy(hiddenOnLockScreen: true),
    );

    expect(
      platformSpecifics(call('show'))['visibility'],
      NotificationVisibility.secret.index,
    );
  });

  group('showActivity', () {
    test(
      'Android: the activity channel, default importance, no actions',
      () async {
        await gateway().showActivity(
          osId: 42,
          title: 'Water the plants',
          body: 'Anna commented: Please check the pots',
          payload: '{"account":"a","task":5,"key":"activity:9"}',
        );

        final shown = args(call('show'));
        expect(shown['id'], 42);
        expect(shown['title'], 'Water the plants');
        expect(shown['body'], 'Anna commented: Please check the pots');
        expect(shown['payload'], '{"account":"a","task":5,"key":"activity:9"}');
        final specifics = platformSpecifics(call('show'));
        expect(
          specifics['channelId'],
          LocalNotificationGateway.activityChannelId,
        );
        expect(specifics['channelName'], en.notificationChannelActivity);
        expect(specifics['importance'], Importance.defaultImportance.value);
        expect(specifics['category'], 'social');
        expect(specifics['actions'], anyOf(isNull, isEmpty));
        expect(specifics['visibility'], isNull);
      },
    );

    test('Android: secret while hidden on the lock screen', () async {
      await gateway().showActivity(
        osId: 42,
        title: 't',
        body: 'b',
        payload: 'p',
        privacy: const NotificationPrivacy(hiddenOnLockScreen: true),
      );

      expect(
        platformSpecifics(call('show'))['visibility'],
        NotificationVisibility.secret.index,
      );
    });

    test('iOS: no category, so no task actions', () async {
      await gateway(platform: TargetPlatform.iOS)
          .showActivity(osId: 42, title: 't', body: 'b', payload: 'p');

      final specifics = platformSpecifics(call('show'));
      expect(specifics['categoryIdentifier'], isNull);
      expect(specifics['presentAlert'], isTrue);
    });
  });

  group('capabilities', () {
    test('Android: granted, exact alarms not allowed', () async {
      answers['areNotificationsEnabled'] = true;
      answers['canScheduleExactNotifications'] = false;

      final capabilities = await gateway().capabilities();

      expect(capabilities.permission, NotificationPermission.granted);
      expect(capabilities.exactAlarms, isFalse);
    });

    test('not asked until requestPermission, denied afterwards', () async {
      answers['areNotificationsEnabled'] = false;
      answers['canScheduleExactNotifications'] = true;
      answers['requestNotificationsPermission'] = false;
      final gateway0 = gateway();

      expect(
        (await gateway0.capabilities()).permission,
        NotificationPermission.notAsked,
      );
      final afterRequest = await gateway0.requestPermission();

      expect(call('requestNotificationsPermission'), isNotNull);
      expect(afterRequest.permission, NotificationPermission.denied);
      expect(afterRequest.exactAlarms, isTrue);
      expect(
        preferences.values[LocalNotificationGateway.permissionAskedKey],
        isNotNull,
      );
      expect(
        (await gateway0.capabilities()).permission,
        NotificationPermission.denied,
      );
    });

    test('a failed request still counts as asked', () async {
      answers['areNotificationsEnabled'] = false;
      throwing = (call) => call.method == 'requestNotificationsPermission'
          ? PlatformException(code: 'permissionRequestInProgress')
          : null;

      final capabilities = await gateway().requestPermission();

      expect(capabilities.permission, NotificationPermission.denied);
    });

    test('iOS: from checkPermissions, exact alarms always', () async {
      answers['checkPermissions'] = {'isEnabled': true};
      answers['requestPermissions'] = true;
      final gateway0 = gateway(platform: TargetPlatform.iOS);

      final capabilities = await gateway0.capabilities();
      expect(capabilities.permission, NotificationPermission.granted);
      expect(capabilities.exactAlarms, isTrue);

      await gateway0.requestPermission();
      final request = args(call('requestPermissions'));
      expect(request['alert'], isTrue);
      expect(request['badge'], isTrue);
      expect(request['sound'], isTrue);
    });
  });

  group('settings', () {
    test('exact alarms: the Android request, nothing on iOS', () async {
      answers['requestExactAlarmsPermission'] = true;
      await gateway().openExactAlarmSettings();
      expect(calls.map((c) => c.method), ['requestExactAlarmsPermission']);

      calls.clear();
      await gateway(platform: TargetPlatform.iOS).openExactAlarmSettings();
      expect(calls, isEmpty);
    });

    test('notification settings open on both', () async {
      answers['openAppNotificationSettings'] = true;
      await gateway().openNotificationSettings();
      await gateway(platform: TargetPlatform.iOS).openNotificationSettings();

      expect(calls.map((c) => c.method), [
        'openAppNotificationSettings',
        'openAppNotificationSettings',
      ]);
    });

    test('a settings page that cannot open is not an error', () async {
      throwing = (call) => call.method == 'requestExactAlarmsPermission'
          ? PlatformException(code: 'permissionRequestInProgress')
          : null;

      await gateway().openExactAlarmSettings();
    });
  });

  group('device localizations', () {
    final unshipped = unshippedLanguageWithArb();
    final noUnshipped = unshipped == null
        ? 'every language with an ARB file ships'
        : null;

    test("the engine's locales resolve as MaterialApp resolves them, and "
        'the result is noted', () async {
      // MaterialApp takes the exact en over the language match of de_AT
      // below the first locale.
      for (final (locales, resolved) in [
        (const [Locale('fr'), Locale('de', 'AT')], 'de'),
        (const [Locale('fr'), Locale('de', 'AT'), Locale('en')], 'en'),
      ]) {
        final l10n = await loadDeviceAppLocalizations(
          preferences,
          locales: locales,
        );

        expect(l10n.localeName, resolved, reason: '$locales');
        expect(preferences.values[notificationLocaleKey], resolved);
      }
    });

    test('a language with an ARB file that is not shipped is passed over, '
        'or falls back to English', () async {
      final passedOver = await loadDeviceAppLocalizations(
        preferences,
        locales: [unshipped!, const Locale('de')],
      );
      expect(passedOver.localeName, 'de');
      expect(preferences.values[notificationLocaleKey], 'de');

      final alone = await loadDeviceAppLocalizations(
        preferences,
        locales: [unshipped],
      );
      expect(alone.localeName, 'en');
      expect(preferences.values[notificationLocaleKey], 'en');
    }, skip: noUnshipped);

    test('a noted language with an ARB file that is not shipped gives '
        'English', () async {
      preferences.values[notificationLocaleKey] = unshipped!.toLanguageTag();

      final l10n = await loadDeviceAppLocalizations(
        preferences,
        locales: const [],
      );

      expect(l10n.localeName, 'en');
    }, skip: noUnshipped);

    test('an engine with only unsupported locales gets English, which is '
        'noted too', () async {
      preferences.values[notificationLocaleKey] = 'de';

      final l10n = await loadDeviceAppLocalizations(
        preferences,
        locales: const [Locale('fr')],
      );

      expect(l10n.localeName, 'en');
      expect(preferences.values[notificationLocaleKey], 'en');
    });

    group('follow', () {
      late ProviderContainer container;

      setUp(() {
        container = ProviderContainer(
          overrides: [
            preferencesStoreProvider.overrideWithValue(preferences),
            deviceAppLocalizationsProvider.overrideWithBuild((_, _) => en),
          ],
        );
        addTearDown(container.dispose);
      });

      DeviceAppLocalizations notifier() =>
          container.read(deviceAppLocalizationsProvider.notifier);

      test('switches to the first supported locale and notes it', () async {
        final changes = <String>[];
        container.listen(
          deviceAppLocalizationsProvider,
          (_, next) => changes.add(next.localeName),
        );

        await notifier().follow(const [Locale('fr'), Locale('de', 'AT')]);

        expect(changes, ['de']);
        expect(preferences.values[notificationLocaleKey], 'de');
      });

      test('the same language, or no locale at all, changes and notes '
          'nothing', () async {
        final changes = <String>[];
        container.listen(
          deviceAppLocalizationsProvider,
          (_, next) => changes.add(next.localeName),
        );

        await notifier().follow(const [Locale('en', 'GB')]);
        await notifier().follow(const []);

        expect(changes, isEmpty);
        expect(preferences.values, isEmpty);
      });
    });

    test(
      'an engine without locales takes the noted tag, else English',
      () async {
        expect(
          (await loadDeviceAppLocalizations(
            preferences,
            locales: const [],
          )).localeName,
          'en',
        );

        preferences.values[notificationLocaleKey] = 'de-DE';
        expect(
          (await loadDeviceAppLocalizations(
            preferences,
            locales: const [],
          )).localeName,
          'de',
        );

        preferences.values[notificationLocaleKey] = 'fr';
        expect(
          (await loadDeviceAppLocalizations(
            preferences,
            locales: const [],
          )).localeName,
          'en',
        );
      },
    );
  });

  group('responses', () {
    test('the launch tap, only when a notification launched the app', () async {
      answers['getNotificationAppLaunchDetails'] = {
        'notificationLaunchedApp': true,
        'notificationResponse': {
          'notificationId': 77,
          'notificationResponseType': 0,
          'payload': 'p',
        },
      };
      final launch = await gateway().launchResponse();
      expect(launch?.id, 77);
      expect(launch?.payload, 'p');
      expect(
        launch?.notificationResponseType,
        NotificationResponseType.selectedNotification,
      );

      answers['getNotificationAppLaunchDetails'] = {
        'notificationLaunchedApp': false,
      };
      expect(await gateway().launchResponse(), isNull);
    });

    test('a tap while running reaches the callback', () async {
      await gateway().initialize();

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            _channel.name,
            _channel.codec.encodeMethodCall(
              const MethodCall('didReceiveNotificationResponse', {
                'notificationId': 77,
                'notificationResponseType': 1,
                'actionId': 'mark_done',
                'payload': 'p',
              }),
            ),
            (_) {},
          );

      expect(responses, hasLength(1));
      expect(responses.single.actionId, 'mark_done');
      expect(responses.single.payload, 'p');
    });

    test(
      'NotificationResponses keeps what arrived before a listener',
      () async {
        final bus = NotificationResponses();
        const early = NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: 'early',
        );
        const late = NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: 'late',
        );
        bus.add(early);

        final received = <NotificationResponse>[];
        final subscription = bus.stream.listen(received.add);
        bus.add(late);
        await Future<void>.delayed(Duration.zero);

        expect(received.map((r) => r.payload), ['early', 'late']);
        await subscription.cancel();
        bus
          ..dispose()
          ..add(early);
      },
    );
  });
}
