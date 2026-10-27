import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/bootstrap/logging_setup.dart';

const _jwt =
    'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJsb2ctbWFya2VyIn0.c2lnbmF0dXJlLW1hcmtlcg';
final String _refreshToken = 'c0ffee42' * 32;

final class _Unprintable {
  @override
  String toString() => throw StateError('no text');
}

// Plain tests: a widget test's binding swaps FlutterError.onError itself.
void main() {
  late List<String> printed;
  late List<LogRecord> records;

  setUp(() {
    final debugPrintBefore = debugPrint;
    final flutterErrorBefore = FlutterError.onError;
    final uncaughtBefore = PlatformDispatcher.instance.onError;
    final levelBefore = Logger.root.level;
    printed = [];
    records = [];
    debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
    final subscription = Logger.root.onRecord.listen(records.add);
    addTearDown(() async {
      resetLoggingForTest();
      await subscription.cancel();
      debugPrint = debugPrintBefore;
      FlutterError.onError = flutterErrorBefore;
      PlatformDispatcher.instance.onError = uncaughtBefore;
      Logger.root.level = levelBefore;
    });
  });

  // Also what goes through `print` instead of `debugPrint`.
  T capturingPrints<T>(T Function() body) => runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (_, _, _, line) => printed.add(line),
    ),
  );

  FlutterErrorDetails detailsOf(Object exception) =>
      FlutterErrorDetails(exception: exception, stack: StackTrace.current);

  bool reportBoth(Object flutterError, Object uncaught) {
    FlutterError.reportError(detailsOf(flutterError));
    return PlatformDispatcher.instance.onError!(uncaught, StackTrace.current);
  }

  test('installs both hooks in a release build too, where they print '
      'nothing and keep the engine from printing', () {
    final flutterErrorBefore = FlutterError.onError;

    final handled = capturingPrints(() {
      configureLogging(printToConsole: false);
      return reportBoth(
        const FormatException('Unexpected end', '{"access_token":"$_jwt"}'),
        FormatException('Unexpected end', '{"refresh_token":"$_refreshToken'),
      );
    });

    expect(FlutterError.onError, isNot(same(flutterErrorBefore)));
    expect(handled, isTrue);
    expect(printed, isEmpty);
    expect(records, isEmpty);
  });

  test('in a debug build, logs uncaught errors redacted through the console '
      "sink, never Flutter's own error dump", () {
    final handled = capturingPrints(() {
      configureLogging();
      return reportBoth(
        const FormatException('Unexpected end', '{"access_token":"$_jwt"}'),
        FormatException('Bad refresh', 'refresh_token=$_refreshToken'),
      );
    });

    expect(handled, isTrue);
    expect(records.map((r) => (r.loggerName, r.level)), [
      ('Flutter', Level.SEVERE),
      ('Uncaught', Level.SEVERE),
    ]);
    expect(records.map((r) => r.stackTrace), everyElement(isNotNull));
    final output = [...records.map((r) => r.message), ...printed].join('\n');
    expect(output, contains('FormatException'));
    expect(output, contains('[redacted]'));
    expect(output, isNot(contains(_jwt)));
    expect(output, isNot(contains(_refreshToken)));
    expect(printed.first, startsWith('SEVERE Flutter: FormatException'));
    expect(printed, everyElement(isNot(contains('EXCEPTION CAUGHT'))));
  });

  test("survives an error whose text can't be built, and still keeps the "
      'engine from printing', () {
    final handled = capturingPrints(() {
      configureLogging();
      return reportBoth(_Unprintable(), _Unprintable());
    });

    expect(handled, isTrue);
    expect(records.map((r) => r.message), everyElement('_Unprintable'));
    expect(records, hasLength(2));
  });

  test('configures an isolate once, and the test reset puts the handlers '
      'back', () {
    final flutterErrorBefore = FlutterError.onError;
    final uncaughtBefore = PlatformDispatcher.instance.onError;

    configureLogging();
    configureLogging(printToConsole: false);
    Logger('Probe').info('once');

    expect(Logger.root.level, Level.ALL);
    expect(printed, ['INFO Probe: once']);

    resetLoggingForTest();

    expect(FlutterError.onError, same(flutterErrorBefore));
    expect(PlatformDispatcher.instance.onError, same(uncaughtBefore));
    expect(Logger.root.level, Level.INFO);
    Logger('Probe').info('after');
    expect(printed, ['INFO Probe: once']);
  });
}
