import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/bootstrap/logging_setup.dart';
import 'package:vikunja_mobile/core/logging/diagnostics_log.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';

const _jwt =
    'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJsb2ctbWFya2VyIn0.c2lnbmF0dXJlLW1hcmtlcg';
final String _refreshToken = 'c0ffee42' * 32;
const _title = 'Garden TITLE-MARKER plan';

final class _Unprintable {
  @override
  String toString() => throw StateError('no text');
}

Future<Directory?> _noFolder() async => null;

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

  // As a release build prints it: the app's frames between the framework's.
  final stack = StackTrace.fromString('''
#0      _TaskRowState.build (package:vikunja_mobile/features/tasks/presentation/task_row.dart:120:7)
#1      StatefulElement.build (package:flutter/src/widgets/framework.dart:5912:27)
#2      main.<anonymous closure> (file:///app/test/some_test.dart:3:5)
#3      TaskList.build (package:vikunja_mobile/features/tasks/presentation/task_list.dart:42)
<asynchronous suspension>
''');

  FlutterErrorDetails detailsOf(Object exception) => FlutterErrorDetails(
    exception: exception,
    stack: stack,
    library: 'widgets library',
  );

  bool reportBoth(Object flutterError, Object uncaught) {
    FlutterError.reportError(detailsOf(flutterError));
    return PlatformDispatcher.instance.onError!(uncaught, stack);
  }

  test('installs both hooks in a release build too, where they print '
      'nothing and keep the engine from printing', () {
    final flutterErrorBefore = FlutterError.onError;

    final handled = capturingPrints(() {
      configureLogging(
        part: AppPart.app,
        printToConsole: false,
        diagnosticsDirectory: _noFolder,
      );
      return reportBoth(
        const FormatException('Unexpected end', '{"access_token":"$_jwt"}'),
        FormatException('Unexpected end', '{"refresh_token":"$_refreshToken'),
      );
    });

    expect(FlutterError.onError, isNot(same(flutterErrorBefore)));
    expect(handled, isTrue);
    expect(printed, isEmpty);
    expect(Logger.root.level, Level.WARNING);
  });

  test('a release build keeps warnings and errors in the diagnostics log, '
      'uncaught ones by type and the frames of the app only', () {
    capturingPrints(() {
      configureLogging(
        part: AppPart.backgroundRun,
        printToConsole: false,
        diagnosticsDirectory: _noFolder,
      );
      Logger('Probe').info('not kept');
      Logger('Probe').warning('kept');
      reportBoth(
        const FormatException('Bad title', _title),
        StateError('refresh_token=$_refreshToken $_title'),
      );
    });

    final entries = currentDiagnosticsLog!.entries;
    expect(printed, isEmpty);
    expect(
      entries.map((e) => (e.part, e.level, e.logger, e.message, e.error)),
      [
        ('backgroundRun', 'WARNING', 'Probe', 'kept', null),
        (
          'backgroundRun',
          'SEVERE',
          'Flutter',
          'Uncaught error (widgets library)',
          'FormatException',
        ),
        ('backgroundRun', 'SEVERE', 'Uncaught', 'Uncaught error', 'StateError'),
      ],
    );
    const tasks = 'package:vikunja_mobile/features/tasks/presentation';
    expect(entries[1].frames, [
      '$tasks/task_row.dart:120:7 _TaskRowState.build',
      '$tasks/task_list.dart:42 TaskList.build',
    ]);
    expect(entries[2].frames, entries[1].frames);
    final kept = entries.map((e) => e.toJson()).join('\n');
    expect(kept, isNot(contains('TITLE-MARKER')));
    expect(kept, isNot(contains(_refreshToken)));
    expect(kept, isNot(contains('Bad title')));
  });

  test('in a debug build, logs uncaught errors redacted through the console '
      "sink, never Flutter's own error dump", () {
    final handled = capturingPrints(() {
      configureLogging(part: AppPart.app, diagnosticsDirectory: _noFolder);
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
    expect(currentDiagnosticsLog!.entries.map((e) => (e.message, e.error)), [
      ('Uncaught error (widgets library)', 'FormatException'),
      ('Uncaught error', 'FormatException'),
    ]);
  });

  test("survives an error whose text can't be built, and still keeps the "
      'engine from printing', () {
    final handled = capturingPrints(() {
      configureLogging(part: AppPart.app, diagnosticsDirectory: _noFolder);
      return reportBoth(_Unprintable(), _Unprintable());
    });

    expect(handled, isTrue);
    expect(records.map((r) => r.message), everyElement('_Unprintable'));
    expect(records, hasLength(2));
    expect(
      currentDiagnosticsLog!.entries.map((e) => e.error),
      everyElement('_Unprintable'),
    );
  });

  test('configures an isolate once, and the test reset puts the handlers '
      'back', () {
    final flutterErrorBefore = FlutterError.onError;
    final uncaughtBefore = PlatformDispatcher.instance.onError;

    configureLogging(part: AppPart.app, diagnosticsDirectory: _noFolder);
    final log = currentDiagnosticsLog;
    configureLogging(
      part: AppPart.widgetAction,
      printToConsole: false,
      diagnosticsDirectory: _noFolder,
    );
    Logger('Probe').info('once');

    expect(Logger.root.level, Level.ALL);
    expect(printed, ['INFO Probe: once']);
    expect(currentDiagnosticsLog, same(log));
    expect(log!.part, AppPart.app);

    resetLoggingForTest();

    expect(FlutterError.onError, same(flutterErrorBefore));
    expect(PlatformDispatcher.instance.onError, same(uncaughtBefore));
    expect(Logger.root.level, Level.INFO);
    expect(currentDiagnosticsLog, isNull);
    Logger('Probe').info('after');
    Logger('Probe').warning('after');
    expect(printed, ['INFO Probe: once']);
    expect(log.entries, isEmpty);
  });

  test('writes the diagnostics log into the folder it is given', () async {
    final folder = await Directory.systemTemp.createTemp('diagnostics');
    addTearDown(() => folder.delete(recursive: true));

    configureLogging(
      part: AppPart.notificationAction,
      printToConsole: false,
      diagnosticsDirectory: () async => folder,
    );
    Logger('Probe').severe('kept');
    await currentDiagnosticsLog!.idle;

    final files = folder.listSync().whereType<File>().toList();
    expect(files, hasLength(1));
    expect(files.single.path, contains('notificationAction-'));
    expect(files.single.readAsStringSync(), contains('"message":"kept"'));
  });
}
