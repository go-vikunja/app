import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_data_source.dart';
import 'package:vikunja_app/data/models/task_attachment_dto.dart';
import 'package:vikunja_app/data/models/user_dto.dart';

class _SettingsDatasource implements SettingsDatasource {
  String? token;

  @override
  Future<String?> getUserToken() async => token;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client extends Client {
  final http.Client transport;

  _Client(this.transport) : super(base: 'https://vikunja.example.com');

  @override
  http.Client createClient() => transport;
}

TaskAttachmentDto _attachment() {
  return TaskAttachmentDto(
    id: 7,
    taskId: 3,
    createdBy: UserDto(username: 'tester'),
    file: TaskAttachmentFileDto(
      id: 8,
      created: DateTime.utc(2026),
      mime: 'application/octet-stream',
      name: 'evidence.bin',
      size: 4,
    ),
  );
}

void main() {
  test(
    'downloads attachment through Client and writes response bytes',
    () async {
      final expectedBytes = <int>[0, 1, 2, 255];
      final settings = _SettingsDatasource()..token = 'attachment-token';
      final client = _Client(
        http_testing.MockClient((request) async {
          expect(request.url.path, '/api/v1/tasks/3/attachments/7');
          expect(request.headers['Authorization'], 'Bearer attachment-token');
          return http.Response.bytes(expectedBytes, 200);
        }),
      )..settingsDatasource = settings;
      String? writtenPath;
      List<int>? writtenBytes;
      final dataSource = TaskDataSource(
        client,
        attachmentPath: (_) async => '/test/evidence.bin',
        writeAttachment: (path, bytes) async {
          writtenPath = path;
          writtenBytes = await bytes.expand((chunk) => chunk).toList();
        },
      );

      final update = await dataSource.downloadAttachment(3, _attachment());

      expect(update.status, TaskStatus.complete);
      expect(update.responseStatusCode, 200);
      expect(writtenPath, '/test/evidence.bin');
      expect(writtenBytes, expectedBytes);
    },
  );

  test('does not write an attachment when the server rejects it', () async {
    final client = _Client(
      http_testing.MockClient((_) async => http.Response('forbidden', 403)),
    )..settingsDatasource = _SettingsDatasource();
    var wroteFile = false;
    final dataSource = TaskDataSource(
      client,
      attachmentPath: (_) async => '/test/evidence.bin',
      writeAttachment: (_, _) async => wroteFile = true,
    );

    final update = await dataSource.downloadAttachment(3, _attachment());

    expect(update.status, TaskStatus.failed);
    expect(update.exception, isA<TaskHttpException>());
    expect(update.responseStatusCode, 403);
    expect(wroteFile, isFalse);
  });

  test('streams attachment bytes to the file writer', () async {
    final chunks = StreamController<List<int>>();
    final client = _Client(_StreamingHttpClient(chunks.stream))
      ..settingsDatasource = _SettingsDatasource();
    var writerStarted = false;
    var downloadCompleted = false;
    final written = <int>[];
    final dataSource = TaskDataSource(
      client,
      attachmentPath: (_) async => '/test/evidence.bin',
      writeAttachment: (_, bytes) async {
        writerStarted = true;
        await for (final chunk in bytes) {
          written.addAll(chunk);
        }
      },
    );

    final download = dataSource.downloadAttachment(3, _attachment()).then((
      value,
    ) {
      downloadCompleted = true;
      return value;
    });
    await Future<void>.delayed(Duration.zero);

    expect(writerStarted, isTrue);
    expect(downloadCompleted, isFalse);

    chunks.add([0, 1]);
    chunks.add([2, 255]);
    await chunks.close();

    final update = await download;
    expect(update.status, TaskStatus.complete);
    expect(written, [0, 1, 2, 255]);
  });

  test('removes a partial attachment when streaming fails', () async {
    final directory = await Directory.systemTemp.createTemp(
      'vikunja-attachment-',
    );
    final path = '${directory.path}/evidence.bin';
    final client = _Client(_StreamingHttpClient(_failingAttachmentStream()))
      ..settingsDatasource = _SettingsDatasource();
    final dataSource = TaskDataSource(
      client,
      attachmentPath: (_) async => path,
    );

    try {
      final update = await dataSource.downloadAttachment(3, _attachment());

      expect(update.status, TaskStatus.failed);
      expect(await File(path).exists(), isFalse);
      expect(await File('$path.part').exists(), isFalse);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

Stream<List<int>> _failingAttachmentStream() async* {
  yield [0, 1];
  throw StateError('connection interrupted');
}

class _StreamingHttpClient extends http.BaseClient {
  final Stream<List<int>> responseBody;

  _StreamingHttpClient(this.responseBody);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(responseBody, 200);
  }
}
