import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/platform/app_language_settings.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<String> calls;
  late Object? Function(MethodCall call) answer;
  late AppExcursions excursions;

  setUp(() {
    calls = [];
    answer = (_) => true;
    messenger.setMockMethodCallHandler(deviceChannel, (call) async {
      calls.add(call.method);
      return answer(call);
    });
    excursions = AppExcursions(now: () => DateTime.utc(2026, 10, 29, 9));
    addTearDown(() {
      messenger.setMockMethodCallHandler(deviceChannel, null);
      excursions.dispose();
    });
  });

  PlatformAppLanguageSettings settings({
    bool android = false,
    bool ios = false,
  }) => PlatformAppLanguageSettings(
    excursions: excursions,
    android: android,
    ios: ios,
  );

  group('available', () {
    test("on Android 13 and later where the activity can open the system's "
        'per-app language page', () async {
      expect(await settings(android: true).available(), isTrue);
      expect(calls, ['canOpenAppLocaleSettings']);
    });

    test('not on Android 12 and older, where the activity cannot', () async {
      answer = (_) => false;

      expect(await settings(android: true).available(), isFalse);
    });

    test('always on iOS, whose app settings page has the language, without '
        'asking', () async {
      expect(await settings(ios: true).available(), isTrue);
      expect(calls, isEmpty);
    });

    test('never elsewhere', () async {
      expect(await settings().available(), isFalse);
      expect(await settings().open(), isFalse);
      expect(calls, isEmpty);
    });
  });

  group('open', () {
    testWidgets("asks for the per-app language page on Android and the app's "
        'settings page on iOS, and says whether it opened', (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      expect(await settings(android: true).open(), isTrue);
      expect(await settings(ios: true).open(), isTrue);
      answer = (_) => false;
      expect(await settings(android: true).open(), isFalse);

      expect(calls, [
        'openAppLocaleSettings',
        'openAppSettings',
        'openAppLocaleSettings',
      ]);
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(excursions.active, isFalse);
    });
  });

  group('the row', () {
    ProviderContainer containerWith(AppLanguageSettings settings) {
      final container = ProviderContainer(
        overrides: [appLanguageSettingsProvider.overrideWithValue(settings)],
      );
      addTearDown(container.dispose);
      return container;
    }

    for (final failure in [
      MissingPluginException(),
      PlatformException(code: 'unavailable'),
    ]) {
      test('is hidden when the channel answers with '
          '${failure.runtimeType}', () async {
        answer = (_) => throw failure;
        final container = containerWith(settings(android: true));

        expect(
          await container.read(appLanguageSettingsAvailableProvider.future),
          isFalse,
        );
      });
    }

    test('shows once the platform said the page is there', () async {
      final container = containerWith(settings(android: true));

      expect(
        await container.read(appLanguageSettingsAvailableProvider.future),
        isTrue,
      );
    });
  });
}
