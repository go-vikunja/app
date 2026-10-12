import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

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

  final notification = ScheduledNotification(
    osId: 77,
    fireAt: DateTime.utc(2026, 10, 13, 8, 30),
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
        'cancel',
      ]);
      final init = args(call('initialize'));
      expect(init['defaultIcon'], LocalNotificationGateway.androidIcon);
      expect(init['dispatcher_handle'], isA<int>());
      expect(init['callback_handle'], isA<int>());
      final channel = args(call('createNotificationChannel'));
      expect(channel['id'], LocalNotificationGateway.channelId);
      expect(channel['name'], en.notificationChannelReminders);
      expect(
        channel['description'],
        en.notificationChannelRemindersDescription,
      );
      expect(channel['importance'], Importance.high.value);
    });

    test('iOS: the task category with background actions, no prompt', () async {
      // Implied by the first use.
      await gateway(platform: TargetPlatform.iOS).cancel(1);

      expect(calls.map((c) => c.method), ['initialize', 'cancel']);
      final init = args(call('initialize'));
      expect(init['requestAlertPermission'], isFalse);
      expect(init['requestBadgePermission'], isFalse);
      expect(init['requestSoundPermission'], isFalse);
      final categories = init['notificationCategories']! as List;
      expect(categories, hasLength(1));
      final category = Map<String, Object?>.from(categories.single as Map);
      expect(category['identifier'], LocalNotificationGateway.darwinCategoryId);
      final actions = (category['actions']! as List)
          .map((a) => Map<String, Object?>.from(a as Map))
          .toList();
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
        expect(action['options'], isEmpty, reason: 'no foreground option');
        expect(action['type'], 'plain');
      }
    });

    test('without a background entry point', () async {
      await gateway(background: false).initialize();

      final init = args(call('initialize'));
      expect(init.containsKey('callback_handle'), isFalse);
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
      expect(scheduled['scheduledDateTime'], '2026-10-13T08:30:00');
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
      expect(scheduled['scheduledDateTime'], '2026-10-13T08:30:00');
      final specifics = platformSpecifics(call('zonedSchedule'));
      expect(
        specifics['categoryIdentifier'],
        LocalNotificationGateway.darwinCategoryId,
      );
      expect(specifics['presentAlert'], isTrue);
      expect(specifics['presentBanner'], isTrue);
      expect(specifics['presentList'], isTrue);
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
    test(
      'the first supported locale of the engine wins and is noted',
      () async {
        final l10n = await loadDeviceAppLocalizations(
          preferences,
          locales: const [Locale('fr'), Locale('de', 'AT'), Locale('en')],
        );

        expect(l10n.localeName, 'de');
        expect(preferences.values[notificationLocaleKey], 'de');
      },
    );

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
