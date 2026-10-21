import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';
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

  group('the secure display', () {
    test("on Android sets and clears the window's flag", () async {
      final display = PlatformSecureDisplay(android: true);

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
      await PlatformSecureDisplay(android: false).setSecure(true);

      expect(deviceCalls, isEmpty);
    });
  });
}
