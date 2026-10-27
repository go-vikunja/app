import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/platform/app_backgrounding.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';
import 'package:vikunja_mobile/core/platform/recents_screenshots.dart';
import 'package:vikunja_mobile/core/platform/secure_display.dart';
import 'package:vikunja_mobile/core/platform/sensitive_clipboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const secret = 'tk_00000000000000000000000000000000000000a1';
  late List<MethodCall> deviceCalls;
  late List<MethodCall> platformCalls;

  setUp(() {
    deviceCalls = [];
    platformCalls = [];
    messenger
      ..setMockMethodCallHandler(deviceChannel, (call) async {
        deviceCalls.add(call);
        return null;
      })
      ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
        platformCalls.add(call);
        return null;
      });
    addTearDown(
      () => messenger
        ..setMockMethodCallHandler(deviceChannel, null)
        ..setMockMethodCallHandler(SystemChannels.platform, null),
    );
  });

  group('the sensitive clipboard', () {
    test(
      'on Android marks the copy sensitive through the device channel',
      () async {
        await PlatformSensitiveClipboard(android: true).copy(secret);

        expect(deviceCalls.single.method, 'copySensitive');
        expect(deviceCalls.single.arguments, {'text': secret});
        expect(platformCalls, isEmpty);
      },
    );

    test('on iOS copies plainly for now', () async {
      await PlatformSensitiveClipboard(android: false).copy(secret);

      expect(deviceCalls, isEmpty);
      expect(platformCalls.single.method, 'Clipboard.setData');
      expect(platformCalls.single.arguments, {'text': secret});
    });

    test('a copy the system refused fails', () async {
      messenger.setMockMethodCallHandler(
        deviceChannel,
        (call) async => throw PlatformException(code: 'unavailable'),
      );

      await expectLater(
        PlatformSensitiveClipboard(android: true).copy(secret),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('the secure window', () {
    test("on Android sets and clears the window's flag", () async {
      final display = PlatformSecureWindow(android: true);

      await display.setSecure(true);
      await display.setSecure(false);

      expect(deviceCalls.map((call) => call.method), [
        'setSecure',
        'setSecure',
      ]);
      expect(deviceCalls.map((call) => call.arguments), [
        {'secure': true},
        {'secure': false},
      ]);
    });

    test('on iOS does nothing for now', () async {
      await PlatformSecureWindow(android: false).setSecure(true);

      expect(deviceCalls, isEmpty);
    });
  });

  group('the Recents screenshot', () {
    test('on Android asks the activity and reports whether it '
        'applied', () async {
      messenger.setMockMethodCallHandler(deviceChannel, (call) async {
        deviceCalls.add(call);
        return true;
      });

      final applied = await PlatformRecentsScreenshots(android: true)
          .setEnabled(false);

      expect(applied, isTrue);
      expect(deviceCalls.single.method, 'setRecentsScreenshotEnabled');
      expect(deviceCalls.single.arguments, {'enabled': false});
    });

    test('below Android 13 the activity answers that it did not', () async {
      messenger.setMockMethodCallHandler(deviceChannel, (call) async => false);

      expect(
        await PlatformRecentsScreenshots(android: true).setEnabled(false),
        isFalse,
      );
    });

    test('on iOS does nothing', () async {
      expect(
        await PlatformRecentsScreenshots(android: false).setEnabled(false),
        isFalse,
      );
      expect(deviceCalls, isEmpty);
    });
  });

  test('moving to the back asks the activity on Android only', () async {
    await PlatformAppBackgrounding(android: true).moveToBack();
    await PlatformAppBackgrounding(android: false).moveToBack();

    expect(deviceCalls.map((call) => call.method), ['moveTaskToBack']);
  });

  test('back moving the app to the back is switched on Android only', () async {
    await PlatformAppBackgrounding(android: true)
        .setBackMovesToBack(enabled: true);
    await PlatformAppBackgrounding(android: false)
        .setBackMovesToBack(enabled: false);

    expect(deviceCalls.map((call) => call.method), ['setBackMovesTaskToBack']);
    expect(deviceCalls.single.arguments, {'enabled': true});
  });
}
