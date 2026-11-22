import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_mobile/core/logging/diagnostics_log.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';

const _jwt =
    'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJsb2ctbWFya2VyIn0.c2lnbmF0dXJlLW1hcmtlcg';
final String _refreshToken = 'c0ffee42' * 32;
const _email = 'marker.user@example.com';
const _title = 'Garden TITLE-MARKER plan';

LogRecord _record(
  String message, {
  Level level = Level.WARNING,
  String logger = 'Probe',
  Object? error,
  StackTrace? stack,
}) => LogRecord(level, message, logger, error, stack);

final _stack = StackTrace.fromString('''
#0      SyncEngineImpl._run (package:vikunja_mobile/core/sync/sync_engine_impl.dart:836:7)
#1      _rootRunUnary (dart:async/zone.dart:1538:47)
#2      ApiClient.get (package:vikunja_api/src/api_client.dart:88:12)
#3      Dio.fetch (package:dio/src/dio_mixin.dart:536:7)
#4      main (file:///app/test/probe_test.dart:1:1)
package:vikunja_logic/src/text/parser.dart 12:5  Parser.parse
package:flutter/src/widgets/framework.dart 5912:27  StatefulElement.build
''');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory folder;
  late DateTime now;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('diagnostics');
    // The real time: pruning compares it with the files' own.
    now = DateTime.now().toUtc();
  });
  tearDown(() => folder.delete(recursive: true));

  DiagnosticsLog log({
    AppPart part = AppPart.app,
    bool withFolder = true,
    int maxEntries = 200,
    int maxBytes = 64 * 1024,
    int seed = 1,
  }) => DiagnosticsLog(
    part: part,
    directory: () async => withFolder ? folder : null,
    now: () => now,
    random: Random(seed),
    maxEntries: maxEntries,
    maxBytes: maxBytes,
  );

  List<File> files() =>
      folder.listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  group('what it keeps', () {
    test('records from WARNING up, redacted, with the error by type and the '
        "app's own frames only", () {
      final diagnostics = log(withFolder: false)
        ..add(_record('only info', level: Level.INFO))
        ..add(
          _record(
            'Request to https://u:pw@tasks.example.org/x?token=abc failed for '
            '$_email with Bearer $_jwt\nand refresh_token=$_refreshToken',
            error: FormatException('Unexpected', '$_title $_refreshToken'),
            stack: _stack,
          ),
        )
        ..add(_record('severe', level: Level.SEVERE, logger: 'Sync Engine!'));

      final [first, second] = diagnostics.entries;
      expect(first.level, 'WARNING');
      expect(first.error, 'FormatException');
      expect(first.message, isNot(contains('\n')));
      for (final secret in [_jwt, _refreshToken, _email, 'pw@', 'abc']) {
        expect(first.message, isNot(contains(secret)));
      }
      expect(first.message, contains('[redacted]'));
      const sync = 'package:vikunja_mobile/core/sync';
      expect(first.frames, [
        '$sync/sync_engine_impl.dart:836:7 SyncEngineImpl._run',
        'package:vikunja_api/src/api_client.dart:88:12 ApiClient.get',
        'package:vikunja_logic/src/text/parser.dart:12:5 Parser.parse',
      ]);
      expect(jsonEncode(first.toJson()), isNot(contains('TITLE-MARKER')));
      expect((second.level, second.logger), ('SEVERE', 'SyncEngine'));
    });

    test('an uncaught error by its type and where Flutter caught it, never '
        'its text', () {
      final diagnostics = log(withFolder: false)
        ..add(
          LogRecord(
            Level.SEVERE,
            '',
            'Flutter',
            null,
            _stack,
            null,
            const UncaughtErrorReport(
              type: FormatException,
              text: 'FormatException: $_title',
              library: 'widgets library',
            ),
          ),
        );

      final entry = diagnostics.entries.single;
      expect(entry.message, 'Uncaught error (widgets library)');
      expect(entry.error, 'FormatException');
      expect(jsonEncode(entry.toJson()), isNot(contains('MARKER')));
    });

    test('long messages and frames are cut', () {
      final diagnostics = log(withFolder: false)..add(_record('x' * 1000));

      expect(diagnostics.entries.single.message.length, lessThan(310));
    });

    test('a record logged again in a row is counted, not kept twice', () {
      final diagnostics = log(withFolder: false)..add(_record('again'));
      now = now.add(const Duration(minutes: 1));
      diagnostics
        ..add(_record('again'))
        ..add(_record('again'));

      final entry = diagnostics.entries.single;
      expect(entry.count, 3);
      expect(entry.at, now);
    });
  });

  group('its bounds', () {
    test('keeps the last maxEntries records', () {
      final diagnostics = log(withFolder: false);
      for (var i = 0; i < 250; i++) {
        diagnostics.add(_record('record $i'));
      }

      expect(diagnostics.entries, hasLength(200));
      expect(diagnostics.entries.first.message, 'record 50');
      expect(diagnostics.entries.last.message, 'record 249');
    });

    test('keeps no more than maxBytes, dropping the oldest', () {
      final diagnostics = log(withFolder: false, maxBytes: 4 * 1024);
      for (var i = 0; i < 100; i++) {
        diagnostics.add(_record('record $i ${'word ' * 40}'));
      }

      final size = diagnostics.entries
          .map((e) => utf8.encode(jsonEncode(e.toJson())).length + 1)
          .fold(0, (sum, length) => sum + length);
      expect(size, lessThanOrEqualTo(4 * 1024));
      expect(diagnostics.entries.length, inInclusiveRange(10, 20));
      expect(diagnostics.entries.last.message, startsWith('record 99 '));
    });

    test('the default bounds are 200 records and 64 KB', () {
      final diagnostics = DiagnosticsLog(part: AppPart.app);

      expect((diagnostics.maxEntries, diagnostics.maxBytes), (200, 65536));
    });
  });

  group('the file', () {
    test("is written soon after a record, and an earlier process's file "
        'stays readable after it ended without a goodbye', () async {
      final crashed = log()..add(_record('before the crash'));
      await crashed.idle;
      expect(files(), hasLength(1));
      expect(p.basename(files().single.path), startsWith('app-'));

      now = now.add(const Duration(minutes: 5));
      final next = log(seed: 2)..add(_record('after the start'));
      final all = await next.readAll();

      expect(all.map((e) => e.message), [
        'before the crash',
        'after the start',
      ]);
      expect(files(), hasLength(2));
    });

    test('holds no secret or content of what was logged', () async {
      final diagnostics = log()
        ..add(
          _record(
            'Failed for $_email with $_jwt',
            error: StateError('$_title refresh_token=$_refreshToken'),
            stack: _stack,
          ),
        );
      await diagnostics.idle;

      final bytes = files().single.readAsStringSync();
      expect(bytes, contains('StateError'));
      for (final secret in [_jwt, _refreshToken, _email, 'TITLE-MARKER']) {
        expect(bytes, isNot(contains(secret)));
      }
    });

    test(
      'every isolate writes its own file, and each reads the others',
      () async {
        final app = log()..add(_record('in the app'));
        now = now.add(const Duration(seconds: 1));
        final background = log(part: AppPart.backgroundRun, seed: 2)
          ..add(_record('in a background run'));
        await Future.wait([app.idle, background.idle]);

        expect(files().map((f) => p.basename(f.path).split('-').first), [
          'app',
          'backgroundRun',
        ]);
        expect((await app.readAll()).map((e) => (e.part, e.message)), [
          ('app', 'in the app'),
          ('backgroundRun', 'in a background run'),
        ]);
      },
    );

    test('the read of all files stays within maxEntries and the retention, '
        'newest kept', () async {
      for (var seed = 1; seed <= 3; seed++) {
        final earlier = log(seed: seed, maxEntries: 5);
        for (var i = 0; i < 5; i++) {
          now = now.add(const Duration(minutes: 1));
          earlier.add(_record('process $seed record $i'));
        }
        await earlier.idle;
      }
      final current = log(seed: 9, maxEntries: 5);

      final all = await current.readAll();
      expect(all.map((e) => e.message), [
        for (var i = 0; i < 5; i++) 'process 3 record $i',
      ]);

      now = now.add(const Duration(days: 7, minutes: 1));
      expect(await current.readAll(), isEmpty);
    });

    test('a start removes files past the retention and keeps three earlier '
        'files of each part', () async {
      for (var seed = 1; seed <= 5; seed++) {
        now = now.add(const Duration(minutes: 1));
        await (log(seed: seed)..add(_record('app $seed'))).idle;
      }
      now = now.add(const Duration(minutes: 1));
      await (log(
        part: AppPart.widgetAction,
        seed: 6,
      )..add(_record('widget'))).idle;
      final stale = File(p.join(folder.path, 'app-1-ab.json.tmp'))
        ..writeAsStringSync('{}')
        ..setLastModifiedSync(DateTime.now().subtract(const Duration(days: 8)));

      final next = log(seed: 7);
      await next.start();

      expect(stale.existsSync(), isFalse);
      final all = await next.readAll();
      expect(all.map((e) => e.message), ['app 3', 'app 4', 'app 5', 'widget']);
    });

    test('a damaged or foreign file is left out', () async {
      File(p.join(folder.path, 'app-1-aa.json')).writeAsStringSync('{"vers');
      File(p.join(folder.path, 'app-2-bb.json'))
          .writeAsStringSync('{"version":2,"entries":[{"message":"x"}]}');
      File(p.join(folder.path, 'app-3-cc.json')).writeAsStringSync(
        jsonEncode({
          'version': 1,
          'entries': [
            {'at': 'never', 'part': 'app', 'level': 'WARNING'},
            {
              'at': now.toIso8601String(),
              'part': 'app',
              'level': 'WARNING',
              'logger': 'Probe',
              'message': 'readable',
            },
          ],
        }),
      );

      final all = await log(seed: 4).readAll();
      expect(all.map((e) => e.message), ['readable']);
    });

    test('without its folder it keeps the records in memory and never '
        'throws', () async {
      final diagnostics = DiagnosticsLog(
        part: AppPart.app,
        directory: () async => throw const FileSystemException('no cache'),
      )..add(_record('kept in memory'));
      await diagnostics.start();
      diagnostics.add(_record('still'));

      expect(diagnostics.file, isNull);
      expect((await diagnostics.readAll()).map((e) => e.message), [
        'kept in memory',
        'still',
      ]);
    });

    test('lives in the cache folder, which backups leave out', () async {
      final channel =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
      channel.setMockMethodCallHandler(
        pathProvider,
        (call) async => switch (call.method) {
          'getApplicationCacheDirectory' => '/cache-root',
          _ => '/elsewhere',
        },
      );
      addTearDown(() => channel.setMockMethodCallHandler(pathProvider, null));

      final directory = await defaultDiagnosticsDirectory();

      expect(directory?.path, '/cache-root/diagnostics');
    });
  });

  group('nothing leaves the device', () {
    final source = File('lib/core/logging/diagnostics_log.dart')
        .readAsStringSync();

    test('the log has no way out: no network, no channel, no share', () {
      final imports = RegExp(
        "^import '([^']+)'",
        multiLine: true,
      ).allMatches(source).map((m) => m[1]);
      expect(imports.toSet(), {
        'dart:async',
        'dart:collection',
        'dart:convert',
        'dart:io',
        'dart:math',
        'package:flutter/foundation.dart',
        'package:logging/logging.dart',
        'package:path/path.dart',
        'package:path_provider/path_provider.dart',
        'package:riverpod_annotation/riverpod_annotation.dart',
        'package:vikunja_mobile/core/logging/redaction.dart',
        'package:vikunja_mobile/core/platform/app_part.dart',
      });
      expect(
        source,
        isNot(
          matches(
            RegExp(
              r'HttpClient|Socket|WebSocket|Process\.|MethodChannel|'
              r'print\(|stdout|stderr',
            ),
          ),
        ),
      );
    });

    test('only the logging setup writes it and only the support details '
        'read it, which leave through the share sheet or the copy of the '
        'release error widget', () {
      const library =
          'package:vikunja_mobile/core/logging/diagnostics_log.dart';
      final users = <String>{
        for (final file in Directory('lib').listSync(recursive: true))
          if (file is File &&
              file.path.endsWith('.dart') &&
              file.readAsStringSync().contains("import '$library';"))
            file.path,
      };
      // The crash reports take a record as the log keeps it
      // (DiagnosticsEntry.capture), never the log itself
      // (decision log: Diagnostics).
      const recordsOnly = {
        'lib/core/crash_reports/crash_reporter.dart',
        'lib/core/crash_reports/sentry_crash_report_sdk.dart',
      };
      expect(users.difference(recordsOnly), {
        'lib/core/logging/logging_setup.dart',
        'lib/features/about/application/support_details.dart',
      });
      for (final path in recordsOnly) {
        expect(
          File(path).readAsStringSync(),
          isNot(
            matches(
              RegExp(
                r'DiagnosticsLog\b|currentDiagnosticsLog|diagnosticsLogProvider|'
                'useDiagnosticsLog|readAll',
              ),
            ),
          ),
          reason: path,
        );
      }
    });
  });
}
