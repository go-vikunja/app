import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/platform/background_permissions.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<String> calls;
  late Object? Function() answer;

  setUp(() {
    calls = [];
    answer = () => null;
    messenger.setMockMethodCallHandler(deviceChannel, (call) async {
      calls.add(call.method);
      return answer();
    });
    addTearDown(() => messenger.setMockMethodCallHandler(deviceChannel, null));
  });

  Future<BackgroundState> read() =>
      PlatformBackgroundPermissions(mobile: true).read();

  test("reads Android's battery, restriction and standby state", () async {
    answer = () => {
      'ignoresBatteryOptimizations': true,
      'powerSaveMode': false,
      'backgroundRestricted': false,
      'standbyBucket': 'workingSet',
    };

    expect(
      await read(),
      const BackgroundState(
        ignoresBatteryOptimizations: true,
        powerSaveMode: false,
        backgroundRestricted: false,
        standbyBucket: 'workingSet',
      ),
    );
    expect(calls, ['backgroundState']);
  });

  test('below Android 9 the restriction and the bucket stay unknown', () async {
    answer = () => {
      'ignoresBatteryOptimizations': false,
      'powerSaveMode': true,
    };

    expect(
      await read(),
      const BackgroundState(
        ignoresBatteryOptimizations: false,
        powerSaveMode: true,
      ),
    );
  });

  test("reads iOS's Background App Refresh and Low Power Mode", () async {
    answer = () => {'backgroundRefresh': 'denied', 'lowPowerMode': true};

    expect(
      await read(),
      const BackgroundState(backgroundRefresh: 'denied', lowPowerMode: true),
    );
  });

  test('a name it does not know reads as other', () async {
    answer = () => {
      'standbyBucket': 'exempted',
      'backgroundRefresh': 'Something <new>',
    };

    expect(
      await read(),
      const BackgroundState(standbyBucket: 'other', backgroundRefresh: 'other'),
    );
  });

  test('a value of the wrong type is unknown', () async {
    answer = () => {
      'ignoresBatteryOptimizations': 'yes',
      'powerSaveMode': 1,
      'standbyBucket': 10,
      'lowPowerMode': null,
    };

    expect(await read(), const BackgroundState());
  });

  test('no answer, an answer that is no map, or a failing call is all '
      'unknown, never an error', () async {
    for (final failing in <Object? Function()>[
      () => null,
      () => ['active'],
      () => throw PlatformException(code: 'failed'),
    ]) {
      answer = failing;
      expect(await read(), const BackgroundState());
    }

    messenger.setMockMethodCallHandler(deviceChannel, null);
    expect(await read(), const BackgroundState());
  });

  test('elsewhere the channel is not asked', () async {
    answer = () => {'powerSaveMode': true};

    expect(
      await PlatformBackgroundPermissions(mobile: false).read(),
      const BackgroundState(),
    );
    expect(calls, isEmpty);
  });
}
