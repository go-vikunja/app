import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';
import '../helpers/task_json.dart';

// The answers were captured by tool/capture_attachment_fixtures.dart: task
// 12827 over v1 (pixel.png 214, the unicode text 215, empty.txt 216), task
// 12828 over v2 (217, 218, 219), task 12826 in an archived project.
const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';
const int _mebibyte = 1024 * 1024;

final Uint8List _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

ServerConnection _connection({required bool hasV2, int? maxFileSizeBytes}) {
  final base = testConnection(hasV2: hasV2);
  return ServerConnection(
    rootUri: base.rootUri,
    apiVersions: base.apiVersions,
    info: ServerInfo(
      version: base.info.version,
      maxFileSizeBytes: maxFileSizeBytes,
    ),
    capabilities: base.capabilities,
  );
}

AttachmentsWritePort _attachments(
  Dio dio, {
  bool hasV2 = true,
  int? maxFileSizeBytes,
}) => createWriteClient(
  dio: dio,
  connection: _connection(hasV2: hasV2, maxFileSizeBytes: maxFileSizeBytes),
).attachments;

TasksWritePort _tasks(Dio dio, {bool hasV2 = true}) => createWriteClient(
  dio: dio,
  connection: testConnection(hasV2: hasV2),
).tasks;

FakeRoute _captured(String name) =>
    capturedFixture('attachments/${name}_2.7.0');

Object? _sent(String name) =>
    fixtureJson('attachments/${name}_2.7.0.json')['sent'];

Future<TaskAttachment> _upload(
  AttachmentsWritePort port,
  int taskId,
  String fileName,
  List<int> bytes, {
  String? mimeType,
  Duration? timeout,
  CancelToken? cancel,
}) => port.upload(
  taskId,
  fileName: fileName,
  bytes: Stream.value(bytes),
  length: bytes.length,
  mimeType: mimeType,
  timeout: timeout,
  cancel: cancel,
);

/// The parts of a multipart body, split at its boundary.
List<({Map<String, String> headers, List<int> content})> _parts(
  RequestOptions request,
  Uint8List body,
) {
  final contentType = request.headers[Headers.contentTypeHeader] as String;
  final boundary = RegExp('boundary=(.+)').firstMatch(contentType)![1]!;
  final text = latin1.decode(body);
  final parts = text.split('--$boundary');
  expect(parts.first, isEmpty);
  expect(parts.last, '--\r\n');
  return [
    for (final part in parts.sublist(1, parts.length - 1))
      () {
        final headerEnd = part.indexOf('\r\n\r\n');
        final headers = {
          for (final line in part.substring(2, headerEnd).split('\r\n'))
            line.substring(0, line.indexOf(':')).toLowerCase(): utf8.decode(
              latin1.encode(line.substring(line.indexOf(':') + 1).trim()),
            ),
        };
        final content = latin1.encode(
          part.substring(headerEnd + 4, part.length - 2),
        );
        return (headers: headers, content: content);
      }(),
  ];
}

DioException _brokenPipe(RequestOptions request) => DioException(
  requestOptions: request,
  error: const SocketException(
    'Broken pipe',
    osError: OSError('Broken pipe', 32),
  ),
);

Matcher _tooLarge(int code) => isA<FileTooLarge>()
    .having((f) => f.code, 'code', code)
    .having((f) => f.statusCode, 'status', 413);

void main() {
  group('upload', () {
    test('v2 posts one part "files" with the name, the type and the bytes, '
        'and returns the attachment', () async {
      final dio = fakeDio({
        '$_v2/tasks/12828/attachments': _captured('v2_upload_png'),
      });

      final attachment = await _upload(
        _attachments(dio),
        12828,
        'pixel.png',
        _pixel,
        mimeType: 'image/png',
      );

      final request = adapterOf(dio).requests.single;
      final body = adapterOf(dio).requestBodyBytes.single!;
      expect(request.method, 'POST');
      expect(
        request.headers[Headers.contentTypeHeader],
        startsWith('multipart/form-data; boundary='),
      );
      expect(request.headers[Headers.contentLengthHeader], '${body.length}');
      final part = _parts(request, body).single;
      expect(
        part.headers['content-disposition'],
        'form-data; name="files"; filename="pixel.png"',
      );
      expect(part.headers['content-type'], 'image/png');
      expect(part.content, _pixel);
      expect(_sent('v2_upload_png'), {
        'file_name': 'pixel.png',
        'length': _pixel.length,
      });
      expect(
        attachment,
        const TaskAttachment(
          id: 217,
          taskId: 12828,
          name: 'pixel.png',
          mime: 'image/png',
          size: 70,
        ),
      );
      expect(attachment.createdBy?.username, 'fixtureuser');
      expect(
        attachment.created,
        DateTime.utc(2026, 10, 20, 17, 24, 6, 279, 922),
      );
    });

    test('v1 puts the same body and parses its answer', () async {
      final dio = fakeDio({
        '$_v1/tasks/12827/attachments': _captured('v1_upload_png'),
      });

      final attachment = await _upload(
        _attachments(dio, hasV2: false),
        12827,
        'pixel.png',
        _pixel,
      );

      final request = adapterOf(dio).requests.single;
      expect(request.method, 'PUT');
      expect(
        _parts(request, adapterOf(dio).requestBodyBytes.single!).single.content,
        _pixel,
      );
      expect(attachment.id, 214);
      expect(attachment.taskId, 12827);
      expect(attachment.size, 70);
    });

    test('a unicode name goes out as UTF-8 and comes back as sent', () async {
      const name = 'Ünïcødé 日本 ü.txt';
      final dio = fakeDio({
        '$_v2/tasks/12828/attachments': _captured('v2_upload_unicode'),
      });

      final attachment = await _upload(
        _attachments(dio),
        12828,
        name,
        utf8.encode('Attachment fixture text.\n'),
      );

      final part = _parts(
        adapterOf(dio).requests.single,
        adapterOf(dio).requestBodyBytes.single!,
      ).single;
      expect(part.headers['content-disposition'], contains('filename="$name"'));
      expect(attachment.name, name);
      expect(attachment.mime, 'text/plain; charset=utf-8');
    });

    test('an empty file is an attachment of 0 bytes', () async {
      final dio = fakeDio({
        '$_v2/tasks/12828/attachments': _captured('v2_upload_empty'),
      });

      final attachment = await _upload(
        _attachments(dio),
        12828,
        'empty.txt',
        const [],
      );

      expect(
        _parts(
          adapterOf(dio).requests.single,
          adapterOf(dio).requestBodyBytes.single!,
        ).single.content,
        isEmpty,
      );
      expect(attachment.id, 219);
      expect(attachment.size, 0);
    });

    test('a blank name is sent as "file": the server takes no name for no '
        'file', () async {
      final dio = fakeDio({
        '$_v2/tasks/12828/attachments': _captured('v2_upload_empty'),
      });

      await _upload(_attachments(dio), 12828, '  ', const []);

      expect(
        _parts(
          adapterOf(dio).requests.single,
          adapterOf(dio).requestBodyBytes.single!,
        ).single.headers['content-disposition'],
        'form-data; name="files"; filename="file"',
      );
    });

    test('a type that does not parse leaves the part to the name', () async {
      final dio = fakeDio({
        '$_v2/tasks/12828/attachments': _captured('v2_upload_png'),
      });

      await _upload(
        _attachments(dio),
        12828,
        'pixel.png',
        _pixel,
        mimeType: 'not a type',
      );

      expect(
        _parts(
          adapterOf(dio).requests.single,
          adapterOf(dio).requestBodyBytes.single!,
        ).single.headers['content-type'],
        'image/png',
      );
    });

    test('the timeout bounds sending and the answer, and a refused token is '
        'not answered with a repeat', () async {
      final dio = fakeDio({
        '$_v2/tasks/12828/attachments': _captured('v2_upload_png'),
      });

      await _upload(
        _attachments(dio),
        12828,
        'pixel.png',
        _pixel,
        timeout: const Duration(minutes: 2),
      );

      final request = adapterOf(dio).requests.single;
      expect(request.sendTimeout, const Duration(minutes: 2));
      expect(request.receiveTimeout, const Duration(minutes: 2));
      expect(request.extra[AuthInterceptor.bodyReadOnceKey], isTrue);
    });

    for (final (name, hasV2, url) in [
      ('v1_upload_too_large', false, '$_v1/tasks/12827/attachments'),
      ('v2_upload_too_large', true, '$_v2/tasks/12828/attachments'),
    ]) {
      test(
        '$name: code 4012 inside the success answer is FileTooLarge',
        () async {
          final dio = fakeDio({url: _captured(name)});

          await expectLater(
            _upload(
              _attachments(dio, hasV2: hasV2),
              hasV2 ? 12828 : 12827,
              'large.bin',
              const [0],
            ),
            throwsA(_tooLarge(4012)),
          );
        },
      );
    }

    for (final (name, hasV2, url) in [
      ('v1_upload_over_request_limit', false, '$_v1/tasks/12827/attachments'),
      ('v2_upload_over_request_limit', true, '$_v2/tasks/12828/attachments'),
    ]) {
      test('$name: 413 code 4035 is FileTooLarge', () async {
        final dio = fakeDio({url: _captured(name)});

        await expectLater(
          _upload(
            _attachments(dio, hasV2: hasV2),
            hasV2 ? 12828 : 12827,
            'huge.bin',
            const [0],
          ),
          throwsA(_tooLarge(4035)),
        );
      });
    }

    test("a proxy's 413 without a code is FileTooLarge 4035", () async {
      final dio = fakeDio({
        '$_v2/tasks/12828/attachments': html(
          '<html><body>413 Request Entity Too Large</body></html>',
          status: 413,
        ),
      });

      await expectLater(
        _upload(_attachments(dio), 12828, 'big.bin', const [0]),
        throwsA(_tooLarge(4035)),
      );
    });

    group('a connection closed while sending', () {
      test('is FileTooLarge for a body above the request limit', () async {
        final dio = fakeDio({
          '$_v2/tasks/1/attachments': failsWith(_brokenPipe),
        });

        await expectLater(
          _upload(
            _attachments(dio, maxFileSizeBytes: _mebibyte),
            1,
            'big.bin',
            Uint8List(3 * _mebibyte + 1),
          ),
          throwsA(_tooLarge(4035)),
        );
      });

      test('is a network failure for a body the server takes', () async {
        final dio = fakeDio({
          '$_v2/tasks/1/attachments': failsWith(_brokenPipe),
        });

        await expectLater(
          _upload(
            _attachments(dio, maxFileSizeBytes: 20 * _mebibyte),
            1,
            'photo.jpg',
            Uint8List(3 * _mebibyte + 1),
          ),
          throwsA(isA<NetworkFailure>()),
        );
      });

      test('without a known limit is a network failure, however long the '
          'body', () async {
        final dio = fakeDio({
          '$_v2/tasks/1/attachments': failsWith(_brokenPipe),
        });

        await expectLater(
          _upload(_attachments(dio), 1, 'photo.jpg', Uint8List(6 * _mebibyte)),
          throwsA(isA<NetworkFailure>()),
        );
      });

      test('a refused connection is never taken for one', () async {
        final dio = fakeDio({'$_v2/tasks/1/attachments': refused});

        await expectLater(
          _upload(
            _attachments(dio, maxFileSizeBytes: _mebibyte),
            1,
            'big.bin',
            Uint8List(4 * _mebibyte),
          ),
          throwsA(isA<NetworkFailure>()),
        );
      });
    });

    test('a body the transport has no memory for is FileTooLarge', () async {
      for (final error in <Object>[
        Exception(
          'ClientException: Not enough memory for request body: '
          'java.lang.OutOfMemoryError: Failed to allocate',
        ),
        const OutOfMemoryError(),
      ]) {
        final dio = fakeDio({
          '$_v2/tasks/1/attachments': failsWith(
            (request) => DioException(requestOptions: request, error: error),
          ),
        });

        await expectLater(
          _upload(_attachments(dio), 1, 'video.mp4', const [0]),
          throwsA(_tooLarge(4035)),
          reason: '$error',
        );
      }
    });

    test('an answer without an attachment or an error is unexpected '
        '(v1 for a part without a name)', () async {
      final dio = fakeDio({
        '$_v1/tasks/12827/attachments': _captured('v1_upload_no_file_name'),
      });

      await expectLater(
        _upload(_attachments(dio, hasV2: false), 12827, 'nameless', const [0]),
        throwsA(isA<UnexpectedResponse>()),
      );
    });

    test('a per-file error with another code is a DomainError, one without '
        'a code a ServerFailure', () async {
      final dio = fakeDio({
        '$_v2/tasks/1/attachments': sequence([
          json({
            'errors': [
              {'code': 4999, 'message': 'something else'},
            ],
            'success': null,
          }, status: 201),
          json({
            'errors': [
              {'message': 'open /files/1: no space left on device'},
            ],
            'success': null,
          }, status: 201),
        ]),
      });
      final port = _attachments(dio);

      await expectLater(
        _upload(port, 1, 'a.txt', const [0]),
        throwsA(
          isA<DomainError>()
              .having((f) => f.code, 'code', 4999)
              .having((f) => f, 'type', isNot(isA<FileTooLarge>())),
        ),
      );
      await expectLater(
        _upload(port, 1, 'a.txt', const [0]),
        throwsA(isA<ServerFailure>()),
      );
    });

    for (final (name, hasV2, url) in [
      ('v1_upload_archived', false, '$_v1/tasks/12826/attachments'),
      ('v2_upload_archived', true, '$_v2/tasks/12826/attachments'),
    ]) {
      test('$name: an archived project is DomainError 3008', () async {
        final dio = fakeDio({url: _captured(name)});

        await expectLater(
          _upload(
            _attachments(dio, hasV2: hasV2),
            12826,
            'archived.txt',
            utf8.encode('refused'),
          ),
          throwsA(
            isA<DomainError>()
                .having((f) => f.statusCode, 'status', 412)
                .having((f) => f.code, 'code', 3008),
          ),
        );
      });
    }

    test('switched off on the server, the route is absent', () async {
      final dio = fakeDio({
        '$_v2/tasks/1/attachments': errorFixture('v1_404_route_2.7.0'),
      });

      await expectLater(
        _upload(_attachments(dio), 1, 'a.txt', const [0]),
        throwsA(isA<NotFound>().having((f) => f.routeAbsent, 'absent', true)),
      );
    });

    test('an error of the bytes is rethrown as it is', () async {
      final dio = fakeDio({
        '$_v2/tasks/1/attachments': _captured('v2_upload_png'),
      });
      const gone = FileSystemException('Cannot open file', '/uploads/x');
      final listenedTwice = StateError('Stream has already been listened to');

      for (final error in <Object>[gone, listenedTwice]) {
        await expectLater(
          _attachments(dio).upload(
            1,
            fileName: 'x.png',
            bytes: Stream.error(error),
            length: 70,
          ),
          throwsA(same(error)),
        );
      }
    });

    test('a cancel is rethrown as the DioException', () async {
      final dio = fakeDio({'$_v2/tasks/1/attachments': hangs});
      final cancel = CancelToken();

      final upload = _upload(_attachments(dio), 1, 'a.txt', const [
        0,
      ], cancel: cancel);
      cancel.cancel();

      await expectLater(
        upload,
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
    });
  });

  group('delete', () {
    test('v2 answers 204', () async {
      final dio = fakeDio({
        '$_v2/tasks/12828/attachments/218': _captured('v2_delete'),
      });

      await _attachments(dio).delete(12828, 218);

      final request = adapterOf(dio).requests.single;
      expect(request.method, 'DELETE');
      expect(adapterOf(dio).requestBodies.single, isNull);
    });

    test('v1 answers 200 with a message', () async {
      final dio = fakeDio({
        '$_v1/tasks/12827/attachments/215': _captured('v1_delete'),
      });

      await _attachments(dio, hasV2: false).delete(12827, 215);

      expect(adapterOf(dio).requests.single.method, 'DELETE');
    });

    for (final (name, hasV2, url) in [
      ('v1_delete_unknown', false, '$_v1/tasks/12827/attachments/215'),
      ('v2_delete_unknown', true, '$_v2/tasks/12828/attachments/218'),
    ]) {
      test(
        '$name: one that is gone (404 code 4011) counts as deleted',
        () async {
          final dio = fakeDio({url: _captured(name)});

          await expectLater(
            _attachments(
              dio,
              hasV2: hasV2,
            ).delete(hasV2 ? 12828 : 12827, hasV2 ? 218 : 215),
            completes,
          );
        },
      );
    }

    test('a task that is gone (404 code 4002) is a failure', () async {
      final dio = fakeDio({
        '$_v2/tasks/1/attachments/2': json({
          'code': 4002,
          'message': 'The task does not exist.',
        }, status: 404),
      });

      await expectLater(
        _attachments(dio).delete(1, 2),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 4002)),
      );
    });

    for (final (name, hasV2, url) in [
      ('v1_delete_archived', false, '$_v1/tasks/12826/attachments/213'),
      ('v2_delete_archived', true, '$_v2/tasks/12826/attachments/213'),
    ]) {
      test('$name: an archived project is DomainError 3008', () async {
        final dio = fakeDio({url: _captured(name)});

        await expectLater(
          _attachments(dio, hasV2: hasV2).delete(12826, 213),
          throwsA(isA<DomainError>().having((f) => f.code, 'code', 3008)),
        );
      });
    }
  });

  group('the cover through the task update', () {
    test('v2 patches only the cover', () async {
      final dio = fakeDio({'$_v2/tasks/12828': _captured('v2_cover_set')});

      final task = await _tasks(dio)
          .update(12828, const TaskChanges(coverImageAttachmentId: 217));

      expect(adapterOf(dio).decodedBodies.single, _sent('v2_cover_set'));
      expect(adapterOf(dio).decodedBodies.single, {
        'cover_image_attachment_id': 217,
      });
      expect(task.id, 12828);
    });

    test('v2: the cover left behind by a delete refuses a title edit with '
        '4020, clearing it with the edit goes through', () async {
      final dio = fakeDio({
        '$_v2/tasks/12828': sequence([
          _captured('v2_cover_dangling'),
          _captured('v2_cover_cleared'),
        ]),
      });
      const title = TaskChanges(title: 'Edited after the cover was deleted');

      await expectLater(
        _tasks(dio).update(12828, title),
        throwsA(
          isA<DomainError>()
              .having((f) => f.statusCode, 'status', 400)
              .having((f) => f.code, 'code', 4020),
        ),
      );
      final task = await _tasks(dio).update(
        12828,
        title.merge(const TaskChanges(coverImageAttachmentId: 0)),
      );

      expect(adapterOf(dio).decodedBodies, [
        _sent('v2_cover_dangling'),
        _sent('v2_cover_cleared'),
      ]);
      expect(task.title, 'Edited after the cover was deleted');
    });

    test('v1 refuses the full replace that echoes a deleted cover with '
        '4020', () async {
      final dio = fakeDio({
        '$_v1/tasks/12827': _byMethod({
          'GET': json(
            taskJson(12827, overrides: {'cover_image_attachment_id': 214}),
          ),
          'POST': _captured('v1_cover_dangling'),
        }),
      });

      await expectLater(
        _tasks(dio, hasV2: false).update(
          12827,
          const TaskChanges(title: 'Edited after the cover was deleted'),
        ),
        throwsA(isA<DomainError>().having((f) => f.code, 'code', 4020)),
      );
      expect(
        (adapterOf(dio).decodedBodies.last!
            as Map<String, Object?>)['cover_image_attachment_id'],
        214,
      );
    });

    test('v1 overlays the cover on the task it read', () async {
      final dio = fakeDio({
        '$_v1/tasks/12827': _byMethod({
          'GET': json(
            taskJson(12827, overrides: {'cover_image_attachment_id': 214}),
          ),
          'POST': json(taskJson(12827)),
        }),
      });

      await _tasks(dio, hasV2: false).update(
        12827,
        const TaskChanges(title: 'Edited', coverImageAttachmentId: 0),
      );

      final sent = adapterOf(dio).decodedBodies.last! as Map<String, Object?>;
      expect(sent['cover_image_attachment_id'], 0);
      expect(sent['title'], 'Edited');
    });
  });
}

FakeRoute _byMethod(Map<String, FakeRoute> routes) =>
    (request) => (routes[request.method] ?? refused)(request);
