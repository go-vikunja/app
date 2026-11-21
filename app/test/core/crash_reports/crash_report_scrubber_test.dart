import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart';
import 'package:sqlite3/common.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_scrubber.dart';

const _jwt =
    'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJsb2ctbWFya2VyIn0.c2lnbmF0dXJlLW1hcmtlcg';
const _email = 'alice@example.org';
const _host = 'tasks.example.org';
const _title = 'Garden TITLE-MARKER plan';

String _scrub(String text) => scrubCrashReportText(text, hosts: const [_host]);

void main() {
  group('scrubCrashReportText', () {
    test("keeps the text, without the app's secrets, server addresses, IP "
        'addresses and file paths', () {
      expect(
        _scrub('Bearer $_jwt for $_email'),
        'Bearer [redacted] for [redacted]',
      );
      expect(
        _scrub('GET https://user:pw@$_host:8443/api/v1/tasks/7?token=x#y'),
        'GET https://<server>/api/v1/tasks/7?token=[redacted]',
      );
      expect(
        _scrub("SocketException: Failed host lookup: 'other.example.net'"),
        "SocketException: Failed host lookup: '<server>'",
      );
      expect(
        _scrub(
          'Connection refused (OS Error: Connection refused, errno = 111), '
          'address = 192.168.1.20, port = 54321',
        ),
        'Connection refused (OS Error: Connection refused, errno = 111), '
        'address = <address>, port = 54321',
      );
      expect(
        _scrub('from 10.0.0.7 and fe80::1ff:fe23:4567:890a'),
        'from <address> and <address>',
      );
      expect(
        _scrub('the server $_host said no'),
        'the server <server> said no',
      );
      expect(_scrub('TASKS.EXAMPLE.ORG'), '<server>');
      expect(
        _scrub(
          "Cannot open file, path = '/data/user/0/io.vikunja.app/files/"
          "$_title.pdf'",
        ),
        "Cannot open file, path = '<path>'",
      );
      expect(
        _scrub('at /var/mobile/Containers/Data/Application/A1/Library/x.db'),
        'at <path>',
      );
      expect(
        _scrub('file:///storage/emulated/0/Download/report.png'),
        'file://<path>',
      );
      expect(
        _scrub(
          'SqliteException(2067): UNIQUE constraint failed: tasks.id\n'
          '  Causing statement: INSERT INTO tasks VALUES (?), parameters: '
          '$_title',
        ),
        'SqliteException(2067): UNIQUE constraint failed: tasks.id\n'
        '  Causing statement: <statement>',
      );
    });

    test('leaves what only looks a little like an address', () {
      const text =
          'Null check operator used on a null value at 10:20:30, '
          'package:vikunja_mobile/core/sync/sync.dart:12:5, version 1.2.3';
      expect(_scrub(text), text);
      expect(_scrub('localhost: no'), 'localhost: no');
    });

    test('cuts a long text at 1,000 characters', () {
      final scrubbed = _scrub('word ' * 400);
      expect(scrubbed.length, 1001);
      expect(scrubbed, endsWith('…'));
    });

    test("an account's id, shorter than the redaction's long runs, and any "
        'UUID', () {
      final id = accountIdFor(Uri.parse('https://$_host/'), 7);
      expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));

      expect(
        _scrub('Account $id is not registered'),
        'Account <id> is not registered',
      );
      expect(_scrub('(${id.toUpperCase()})'), '(<id>)');
      expect(
        _scrub(
          'install 0f8fad5b-d9cb-469f-a165-70867728950e and '
          '0F8FAD5B-D9CB-469F-A165-70867728950E',
        ),
        'install <id> and <id>',
      );
      expect(_scrub('guest_$id left'), 'guest_<id> left');
      expect(_scrub('$id-wal'), '<id>-wal');
      expect(_scrub('v-0f8fad5b-d9cb-469f-a165-70867728950e'), 'v-<id>');
      // 40 characters with the id: the redaction's long-run rule comes first.
      expect(_scrub('account_$id.sqlite'), '[redacted].sqlite');
      expect(_scrub('drift-db/account_$id'), 'drift-db/[redacted]');
      for (final kept in [
        '0' * 31,
        '0' * 33,
        'a${'0' * 32}',
        '0f8fad5b-d9cb-469f-a165-70867728950',
      ]) {
        expect(_scrub(kept), kept);
      }
    });
  });

  group('crashReportErrorText', () {
    test('leaves out what the types quote: a source, a path, a statement, '
        "the server's message, a platform's details", () {
      expect(
        crashReportErrorText(
          const FormatException(
            'Unexpected character',
            '{"title":"$_title"}',
            2,
          ),
        ),
        'FormatException: Unexpected character (at offset 2)',
      );
      expect(
        crashReportErrorText(
          const FileSystemException(
            'Cannot open file',
            '/data/$_title',
            OSError('No such file or directory', 2),
          ),
        ),
        'FileSystemException: Cannot open file (OS Error: No such file or '
        'directory, errno = 2)',
      );
      expect(
        crashReportErrorText(
          SqliteException(
            extendedResultCode: 2067,
            message: 'UNIQUE constraint failed: tasks.id',
            causingStatement: 'INSERT INTO tasks VALUES (?)',
            parametersToStatement: const [_title],
          ),
        ),
        'SqliteException(2067): UNIQUE constraint failed: tasks.id',
      );
      expect(
        crashReportErrorText(const NotFound(message: 'Task $_title not found')),
        'NotFound',
      );
      expect(
        crashReportErrorText(
          const NetworkFailure(NetworkProblem.tls, cause: _host),
        ),
        'NetworkFailure(tls)',
      );
      expect(
        crashReportErrorText(
          PlatformException(code: 'read', message: _title, details: _title),
        ),
        'PlatformException(read)',
      );
      expect(
        crashReportErrorText(
          SocketException(
            "Failed host lookup: '$_host'",
            osError: const OSError('nodename nor servname provided', 8),
            address: InternetAddress.loopbackIPv4,
            port: 443,
          ),
        ),
        "SocketException: Failed host lookup: '$_host' (OS Error: nodename "
        'nor servname provided, errno = 8)',
      );
      expect(
        crashReportErrorText(
          DioException.badResponse(
            statusCode: 404,
            requestOptions: RequestOptions(path: 'https://$_host/api'),
            response: Response(
              requestOptions: RequestOptions(),
              statusCode: 404,
              data: {'message': _title},
            ),
          ),
        ),
        'DioException [badResponse] 404',
      );
    });

    test("an error's own text without the strings it quotes; of anything "
        'else only the type', () {
      expect(
        crashReportErrorText(ArgumentError.value(_title, 'title', 'too long')),
        'Invalid argument (title): too long: "…"',
      );
      expect(
        crashReportErrorText(StateError('No element')),
        'Bad state: No element',
      );
      expect(
        crashReportErrorText(Exception('failed with $_title')),
        '_Exception',
      );
      expect(
        crashReportErrorText(const _AppException(_title)),
        '_AppException',
      );
    });
  });

  group('scrubCrashReport', () {
    SentryEvent event() {
      const error = FormatException('Bad JSON', '{"title":"$_title"}');
      return SentryEvent(
        message: SentryMessage(
          'Sync failed for https://$_host/api',
          template: 'Sync failed for %s',
          params: const ['https://$_host/api'],
        ),
        exceptions: [
          SentryException(
            type: 'FormatException',
            value: '$error',
            throwable: error,
            mechanism: Mechanism(
              type: 'FlutterError',
              description: 'from $_email',
              helpLink: 'https://$_host/help',
              data: const {
                'url': 'https://$_host/',
                'library': 'widgets library',
              },
            ),
          ),
          SentryException(type: '_TypeError', value: 'token=abc123 for $_host'),
        ],
        threads: [SentryThread(name: 'isolate $_host')],
        breadcrumbs: [
          Breadcrumb(
            message: 'Retrying https://$_host',
            category: crashReportLogCategory,
            data: const {'error': 'SocketException', 'host': _host},
          ),
          Breadcrumb(message: 'Tapped $_title', category: 'ui.click'),
          Breadcrumb.http(url: Uri.parse('https://$_host/api'), method: 'GET'),
        ],
        tags: const {'server': _host},
        user: SentryUser(
          id: 'installation-id',
          username: 'alice',
          email: _email,
        ),
        request: SentryRequest(url: 'https://$_host/api'),
        serverName: 'alices-phone',
        contexts:
            Contexts(
                device: SentryDevice(
                  name: "Alice's phone",
                  family: 'Pixel',
                  model: 'Pixel 9',
                  modelId: 'AP4A',
                  manufacturer: 'Google',
                  brand: 'google',
                  arch: 'arm64',
                  simulator: false,
                  deviceUniqueIdentifier: 'device-id',
                  batteryLevel: 81,
                  charging: true,
                  freeMemory: 123,
                  freeStorage: 456,
                  bootTime: DateTime.utc(2026, 11),
                  screenDpi: 420,
                  unknown: const {
                    'id': 'installation-id',
                    'archs': ['arm64-v8a'],
                    'timezone': 'Europe/Berlin',
                    'locale': 'de_DE',
                    'connection_type': 'wifi',
                  },
                ),
                app: SentryApp(
                  name: 'Vikunja',
                  version: '1.0.0',
                  identifier: 'io.vikunja.app',
                  build: '7',
                  buildType: 'release',
                  startTime: DateTime.utc(2026, 11),
                  deviceAppHash: 'hash',
                  inForeground: true,
                  viewNames: const ['/home/tasks/7'],
                  unknown: const {
                    'permissions': {'ACCESS_NETWORK_STATE': 'granted'},
                  },
                ),
                operatingSystem: SentryOperatingSystem(
                  name: 'Android',
                  version: '16',
                  build: 'BP2A.250605',
                  kernelVersion: '6.1.0-android',
                  rooted: false,
                  rawDescription: 'Linux localhost 6.1.0',
                ),
                runtimes: [
                  SentryRuntime(
                    name: 'Dart',
                    version: '3.10.0',
                    compiler: 'AOT',
                    rawDescription: '3.10.0 (stable) on "android_arm64"',
                  ),
                  SentryRuntime(
                    name: 'Flutter',
                    version: '3.38.0',
                    rawDescription:
                        '/data/app/io.vikunja.app/lib/libflutter.so',
                  ),
                ],
                culture: SentryCulture(
                  locale: 'de-DE',
                  timezone: 'Europe/Berlin',
                ),
                gpu: SentryGpu(name: 'Adreno'),
                trace: SentryTraceContext(
                  traceId: SentryId.newId(),
                  spanId: SpanId.newId(),
                  operation: 'ui.load',
                ),
                response: SentryResponse(statusCode: 500),
                feedback: SentryFeedback(message: 'see $_title'),
              )
              ..['custom'] = const {'note': 'see https://$_host', 'count': 3}
              ..['accessibility'] = const {
                'bold_text': true,
                'invert_colors': true,
              }
              ..['flutter_context'] = const {
                'default_route_name': '/home/tasks/7',
              }
              ..['culture_extra'] = 'Europe/Berlin',
      );
    }

    test('removes the user, the request, the server name and the '
        'transaction', () {
      final scrubbed = scrubCrashReport(event(), part: 'app', hosts: [_host]);

      expect(scrubbed.user, isNull);
      expect(scrubbed.request, isNull);
      expect(scrubbed.serverName, isNull);
      expect(scrubbed.transaction, isNull);
    });

    test("keeps only the device's model and system, the app's version and "
        "the runtimes' versions of the contexts", () {
      final contexts = scrubCrashReport(
        event(),
        part: 'app',
        hosts: [_host],
      ).contexts;

      expect(contexts.toJson().keys.toSet(), {
        'device',
        'os',
        'app',
        'dart',
        'flutter',
      });
      expect(contexts.device!.toJson(), {
        'family': 'Pixel',
        'model': 'Pixel 9',
        'model_id': 'AP4A',
        'arch': 'arm64',
        'manufacturer': 'Google',
        'brand': 'google',
        'simulator': false,
        'archs': ['arm64-v8a'],
      });
      expect(contexts.operatingSystem!.toJson(), {
        'name': 'Android',
        'version': '16',
        'build': 'BP2A.250605',
      });
      expect(contexts.app!.toJson(), {
        'app_name': 'Vikunja',
        'app_version': '1.0.0',
        'app_identifier': 'io.vikunja.app',
        'app_build': '7',
        'build_type': 'release',
      });
      expect(
        [for (final runtime in contexts.runtimes) runtime.toJson()],
        [
          {
            'name': 'Dart',
            'version': '3.10.0',
            'raw_description': '3.10.0 (stable) on "android_arm64"',
          },
          {'name': 'Flutter', 'version': '3.38.0'},
        ],
      );
      for (final gone in [
        contexts.culture,
        contexts.gpu,
        contexts.trace,
        contexts.response,
        contexts.feedback,
        contexts['accessibility'],
        contexts['flutter_context'],
        contexts['custom'],
        contexts['culture_extra'],
      ]) {
        expect(gone, isNull);
      }
    });

    test('scrubs every text: the message, exception values and mechanisms, '
        "threads, breadcrumbs, tags; keeps only the app's own breadcrumbs "
        'and tags the part', () {
      final scrubbed = scrubCrashReport(
        event(),
        part: 'backgroundRun',
        hosts: [_host],
      );

      expect(
        scrubbed.message!.formatted,
        'Sync failed for https://<server>/api',
      );
      expect(scrubbed.message!.params, isNull);
      expect(scrubbed.message!.template, isNull);
      expect(scrubbed.exceptions!.first.value, 'FormatException: Bad JSON');
      expect(
        scrubbed.exceptions!.first.mechanism!.description,
        'from [redacted]',
      );
      expect(scrubbed.exceptions!.first.mechanism!.data, {
        'library': 'widgets library',
      });
      expect(scrubbed.exceptions!.first.mechanism!.helpLink, isNull);
      expect(scrubbed.exceptions!.last.value, isNull);
      expect(scrubbed.exceptions!.last.type, '_TypeError');
      expect(scrubbed.threads!.single.name, 'isolate <server>');
      expect(scrubbed.breadcrumbs, hasLength(1));
      expect(scrubbed.breadcrumbs!.single.message, 'Retrying https://<server>');
      expect(scrubbed.breadcrumbs!.single.data, {
        'error': 'SocketException',
        'host': '<server>',
      });
      expect(scrubbed.tags, {
        'server': '<server>',
        'app.part': 'backgroundRun',
      });

      final json = '${scrubbed.toJson()}';
      for (final secret in [
        _host,
        _email,
        _title,
        'alice',
        'installation-id',
        'device-id',
        'hash',
        'Europe/Berlin',
        'de_DE',
        'wifi',
        'granted',
        '/home/tasks/7',
        'libflutter',
      ]) {
        expect(json, isNot(contains(secret)), reason: secret);
      }
    });

    test('a PlatformException: of its mechanism data only the code and the '
        'library; of a Java exception parsed from its details, which has '
        'no throwable, only the type and the module', () {
      const path =
          '/storage/emulated/0/Download/Bewerbung Max Mustermann.pdf: open '
          'failed';
      final error = PlatformException(
        code: 'open',
        message: 'FileNotFoundException: $path',
      );
      final scrubbed = scrubCrashReport(
        SentryEvent(
          exceptions: [
            SentryException(
              type: 'PlatformException',
              value: '$error',
              throwable: error,
              mechanism: Mechanism(
                type: 'platformException',
                data: {
                  'code': 'open',
                  'message': 'FileNotFoundException: $path',
                  'library': 'services library',
                  'source': 'stackTrace',
                },
              ),
            ),
            SentryException(
              type: 'FileNotFoundException',
              module: 'java.io',
              value: path,
              mechanism: Mechanism(type: 'generic', source: 'causes[0]'),
            ),
          ],
        ),
        part: 'app',
      );

      final [platform, java] = scrubbed.exceptions!;
      expect(platform.value, 'PlatformException(open)');
      expect(platform.mechanism!.data, {
        'code': 'open',
        'library': 'services library',
      });
      expect(java.value, isNull);
      expect(java.type, 'FileNotFoundException');
      expect(java.module, 'java.io');
      expect('${scrubbed.toJson()}', isNot(contains('Mustermann')));
    });

    test('an account that is no longer registered: its StateError keeps '
        'its text without the id, in values, messages and breadcrumbs, '
        'never in the debug images', () {
      final id = accountIdFor(Uri.parse('https://try.vikunja.io/'), 42);
      final error = StateError('Account $id is not registered');
      const uuid = '0f8fad5b-d9cb-469f-a165-70867728950e';
      final scrubbed = scrubCrashReport(
        SentryEvent(
          message: SentryMessage('Could not open account $id'),
          exceptions: [
            SentryException(
              type: 'StateError',
              value: '$error',
              throwable: error,
            ),
          ],
          breadcrumbs: [
            Breadcrumb(
              message: 'Account $id left',
              category: crashReportLogCategory,
            ),
          ],
          debugMeta: DebugMeta(
            images: [DebugImage(type: 'elf', codeId: '0' * 32, debugId: uuid)],
          ),
        ),
        part: 'app',
      );

      expect(
        scrubbed.exceptions!.single.value,
        'Bad state: Account <id> is not registered',
      );
      expect(scrubbed.message!.formatted, 'Could not open account <id>');
      expect(scrubbed.breadcrumbs!.single.message, 'Account <id> left');
      expect(scrubbed.debugMeta!.images.single.codeId, '0' * 32);
      expect(scrubbed.debugMeta!.images.single.debugId, uuid);
      expect('${scrubbed.toJson()}', isNot(contains(id)));
    });

    test("frames and debug images name the app's folders without what "
        'Android and iOS pick at each install; the rest of the path, the '
        'ids and the addresses stay', () {
      const android =
          '/data/app/~~R4nd0mT0k3n_-xYz12345==/'
          'io.vikunja.app-An0th3r-T0k3n_xyz9876==/';
      const bundle = '0F8FAD5B-D9CB-469F-A165-70867728950E';
      const data = '1A2B3C4D-1111-2222-3333-444455556666';
      SentryStackFrame frame(String path) => SentryStackFrame(
        package: path,
        absPath: path,
        fileName: path,
        instructionAddr: '0x7a1b2c3d4e',
        platform: 'native',
      );
      final scrubbed = scrubCrashReport(
        SentryEvent(
          exceptions: [
            SentryException(
              type: 'StateError',
              value: null,
              stackTrace: SentryStackTrace(
                frames: [
                  frame('${android}lib/arm64/libapp.so'),
                  frame(
                    '/private/var/containers/Bundle/Application/$bundle/'
                    'Runner.app/Frameworks/App.framework/App',
                  ),
                  SentryStackFrame(
                    absPath: 'package:vikunja_mobile/core/sync/sync.dart',
                    fileName: 'sync.dart',
                    package: 'vikunja_mobile',
                  ),
                ],
              ),
            ),
          ],
          threads: [
            SentryThread(
              stacktrace: SentryStackTrace(
                frames: [
                  frame('/var/containers/Bundle/Application/$bundle/x'),
                  frame('/var/mobile/Containers/Data/Application/$data/y'),
                  frame('/data/app/io.vikunja.app-2/base.apk'),
                ],
              ),
            ),
          ],
          debugMeta: DebugMeta(
            images: [
              DebugImage(
                type: 'elf',
                codeFile: '${android}lib/arm64/libapp.so',
                debugFile: '${android}lib/arm64/libapp.so',
                codeId: 'a1b2c3d4e5f60718293a4b5c6d7e8f90',
                debugId: 'd4c3b2a1-f6e5-1807-293a-4b5c6d7e8f90',
                imageAddr: '0x7a00000000',
              ),
              DebugImage(
                type: 'macho',
                codeFile:
                    '/private/var/containers/Bundle/Application/$bundle/'
                    'Runner.app/Runner',
                debugId: bundle,
              ),
            ],
          ),
        ),
        part: 'app',
      );

      final frames = [
        ...scrubbed.exceptions!.single.stackTrace!.frames,
        ...scrubbed.threads!.single.stacktrace!.frames,
      ];
      for (final frame in frames.where((frame) => frame.platform != null)) {
        expect(frame.absPath, frame.package);
        expect(frame.fileName, frame.package);
      }
      const appFramework =
          '/private/var/containers/Bundle/Application/app/Runner.app/'
          'Frameworks/App.framework/App';
      expect(
        [for (final frame in frames) frame.package],
        [
          '/data/app/io.vikunja.app/lib/arm64/libapp.so',
          appFramework,
          'vikunja_mobile',
          '/var/containers/Bundle/Application/app/x',
          '/var/mobile/Containers/Data/Application/app/y',
          '/data/app/io.vikunja.app/base.apk',
        ],
      );
      expect(frames[2].absPath, 'package:vikunja_mobile/core/sync/sync.dart');
      expect(frames[2].fileName, 'sync.dart');
      expect(frames.first.instructionAddr, '0x7a1b2c3d4e');
      final [elf, macho] = scrubbed.debugMeta!.images;
      expect(elf.codeFile, '/data/app/io.vikunja.app/lib/arm64/libapp.so');
      expect(elf.debugFile, '/data/app/io.vikunja.app/lib/arm64/libapp.so');
      expect(elf.codeId, 'a1b2c3d4e5f60718293a4b5c6d7e8f90');
      expect(elf.debugId, 'd4c3b2a1-f6e5-1807-293a-4b5c6d7e8f90');
      expect(elf.imageAddr, '0x7a00000000');
      expect(
        macho.codeFile,
        '/private/var/containers/Bundle/Application/app/Runner.app/Runner',
      );
      expect(macho.debugId, bundle);
    });

    test("breadcrumbs: only the app's own, scrubbed", () {
      expect(
        scrubCrashReportBreadcrumb(
          Breadcrumb(message: '/home/tasks/7', category: 'navigation'),
        ),
        isNull,
      );
      expect(
        scrubCrashReportBreadcrumb(
          Breadcrumb(message: 'for $_email', category: crashReportLogCategory),
        )!.message,
        'for [redacted]',
      );
    });
  });
}

final class _AppException implements Exception {
  const new(this.title);

  final String title;

  @override
  String toString() => 'Could not save $title';
}
