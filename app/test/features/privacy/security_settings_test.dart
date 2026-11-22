import 'dart:ui' show AppLifecycleState;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';
import 'package:vikunja_mobile/features/privacy/application/security_settings.dart';

void main() {
  late AppExcursions excursions;
  late List<String> seen;
  late Object? Function() answer;

  setUp(() {
    excursions = AppExcursions(now: () => DateTime.utc(2026, 11, 22, 9));
    addTearDown(excursions.dispose);
    seen = [];
    answer = () => true;
  });

  void mockChannel(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(deviceChannel, (call) async {
        seen.add('${call.method} ${excursions.active}');
        return answer();
      });
    addTearDown(() => messenger.setMockMethodCallHandler(deviceChannel, null));
  }

  testWidgets('a round trip that lasts until the app is back, so leaving '
      'for them does not lock the app', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    mockChannel(tester);

    expect(await openSecuritySettings(excursions), isTrue);
    expect(seen, ['openSecuritySettings true']);
    expect(excursions.active, isTrue);
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(excursions.active, isFalse);
  });

  testWidgets('settings that did not open end the round trip at once', (
    tester,
  ) async {
    mockChannel(tester);
    answer = () => false;

    expect(await openSecuritySettings(excursions), isFalse);
    await tester.pump();
    expect(excursions.active, isFalse);
  });

  testWidgets('a failing channel answers false and never throws', (
    tester,
  ) async {
    mockChannel(tester);
    answer = () => throw PlatformException(code: 'unavailable');

    expect(await openSecuritySettings(excursions), isFalse);
    await tester.pump();
    expect(excursions.active, isFalse);
  });
}
