import 'dart:async';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/bootstrap/start_values.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final de = lookupAppLocalizations(const Locale('de'));
  const identity = ClientIdentity(
    appVersion: '1.0.0',
    buildNumber: '7',
    platform: 'android',
    osVersion: '16',
  );
  late List<LogRecord> records;

  setUp(() {
    records = [];
    final level = Logger.root.level;
    Logger.root.level = Level.ALL;
    final subscription = Logger.root.onRecord.listen(records.add);
    addTearDown(() {
      Logger.root.level = level;
      return subscription.cancel();
    });
  });

  test('the values as loaded', () async {
    final values = await loadStartValues(
      clientIdentity: () async => identity,
      deviceL10n: () async => de,
    );

    expect(values.clientIdentity, same(identity));
    expect(values.deviceL10n, same(de));
    expect(records, isEmpty);
  });

  test('preferences that throw fall back to an identity without versions '
      "and the engine's locales, logged by type", () async {
    final values = await loadStartValues(
      clientIdentity: () async => throw Exception('Unable to parse prefs'),
      deviceL10n: () async => throw Exception('Unable to parse prefs'),
    );

    expect(values.clientIdentity.appVersion, isEmpty);
    expect(values.clientIdentity.platform, Platform.operatingSystem);
    expect(
      values.deviceL10n.localeName,
      deviceAppLocalizationsWithoutNote().localeName,
    );
    expect(records.map((record) => record.level), [Level.SEVERE, Level.SEVERE]);
    expect(
      records.map((record) => record.message),
      everyElement(allOf(contains('_Exception'), isNot(contains('prefs')))),
    );
  });

  test('a call that never answers falls back after the timeout', () async {
    final values = await loadStartValues(
      clientIdentity: () => Completer<ClientIdentity>().future,
      deviceL10n: () async => de,
      timeout: const Duration(milliseconds: 50),
    );

    expect(values.clientIdentity.appVersion, isEmpty);
    expect(values.deviceL10n, same(de));
    expect(records.single.message, contains('TimeoutException'));
  });
}
