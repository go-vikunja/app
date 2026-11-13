import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_platform.dart';

const _notificationsChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<MethodCall> calls;
  late Map<String, Object?> answers;
  late List<MethodCall> notificationCalls;

  setUp(() {
    calls = [];
    answers = {};
    notificationCalls = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          ..setMockMethodCallHandler(deviceChannel, (call) async {
            calls.add(call);
            return answers[call.method];
          })
          ..setMockMethodCallHandler(_notificationsChannel, (call) async {
            notificationCalls.add(call);
            return null;
          });
    addTearDown(() {
      messenger
        ..setMockMethodCallHandler(deviceChannel, null)
        ..setMockMethodCallHandler(_notificationsChannel, null);
    });
    AndroidFlutterLocalNotificationsPlugin.registerWith();
  });

  final platform = ChannelPreviousAppPlatform();

  test('reads the traces', () async {
    answers['previousAppTraces'] = {
      'secureEntries': 4,
      'legacyChannels': true,
      'legacyWidgets': 2,
      'homeWidgetData': true,
      'scheduledNotifications': true,
    };

    expect(
      await platform.traces(),
      const PreviousAppTraces(
        secureEntries: 4,
        legacyChannels: true,
        legacyWidgets: 2,
        homeWidgetData: true,
        scheduledNotifications: true,
      ),
    );
    expect(calls.single.method, 'previousAppTraces');
    expect(calls.single.arguments, isNull);
  });

  for (final (name, answer) in [
    ('no answer', null),
    ('an empty answer', <String, Object?>{}),
    (
      'wrong types',
      {
        'secureEntries': '4',
        'legacyChannels': 'true',
        'legacyWidgets': -1,
        'homeWidgetData': 1,
        'scheduledNotifications': null,
      },
    ),
  ]) {
    test('reads $name as no traces', () async {
      answers['previousAppTraces'] = answer;

      final traces = await platform.traces();

      expect(traces, PreviousAppTraces.none);
      expect(traces.any, isFalse);
    });
  }

  test('each trace alone counts', () {
    for (final traces in const [
      PreviousAppTraces(secureEntries: 1),
      PreviousAppTraces(legacyChannels: true),
      PreviousAppTraces(legacyWidgets: 1),
      PreviousAppTraces(homeWidgetData: true),
      PreviousAppTraces(scheduledNotifications: true),
    ]) {
      expect(traces.any, isTrue, reason: '$traces');
    }
  });

  test('clears the previous app natively', () async {
    await platform.clear();

    expect(calls.single.method, 'clearPreviousApp');
    expect(calls.single.arguments, isNull);
  });

  test('sets the app language and returns the answer', () async {
    answers['setAppLanguage'] = true;

    expect(await platform.setAppLanguage('de'), isTrue);
    expect(calls.single.method, 'setAppLanguage');
    expect(calls.single.arguments, {'language': 'de'});

    answers['setAppLanguage'] = null;
    expect(await platform.setAppLanguage('en'), isFalse);
    answers['setAppLanguage'] = false;
    expect(await platform.setAppLanguage('en'), isFalse);
  });

  test("cancels the notification plugin's alarms and notifications", () async {
    await platform.cancelNotifications();

    expect(notificationCalls.single.method, 'cancelAll');
    expect(calls, isEmpty);
  });
}
