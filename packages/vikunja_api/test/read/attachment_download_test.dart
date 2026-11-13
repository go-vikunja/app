import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';

// The text answers were captured by tool/capture_attachment_fixtures.dart:
// "Ünïcødé 日本 ü.txt", 215 of task 12827 over v1 and 218 of task 12828
// over v2, 25 bytes.
const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';
const _text = 'Attachment fixture text.\n';

AttachmentsPort _attachments(Dio dio, {bool hasV2 = true}) => createReadClient(
  dio: dio,
  connection: testConnection(hasV2: hasV2),
).attachments;

FakeRoute _captured(String name) =>
    capturedFixture('attachments/${name}_2.7.0');

FakeRoute _bytes(List<int> bytes, {int status = 200}) =>
    (_) => ResponseBody.fromBytes(
      bytes,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/octet-stream'],
        Headers.contentLengthHeader: ['${bytes.length}'],
      },
    );

/// Sends [head], then breaks off like a reset connection.
FakeRoute _brokenOff(List<int> head, {required int declared}) => (_) {
  final controller = StreamController<Uint8List>()
    ..add(Uint8List.fromList(head))
    ..addError(const SocketException('Connection reset by peer'));
  unawaited(controller.close());
  return ResponseBody(
    controller.stream,
    200,
    headers: {
      Headers.contentLengthHeader: ['$declared'],
    },
  );
};

/// Sends [head] and then nothing until the request is cancelled.
FakeRoute _stalling(List<int> head, {required Completer<void> sent}) => (_) {
  final controller = StreamController<Uint8List>()
    ..add(Uint8List.fromList(head));
  sent.complete();
  return ResponseBody(controller.stream, 200);
};

void main() {
  late Directory temp;
  late File target;

  File part() => File('${target.path}.part');

  setUp(() {
    temp = Directory.systemTemp.createTempSync('vikunja_download');
    target = File('${temp.path}/attachments/12828/218/notes.txt');
  });

  tearDown(() => temp.deleteSync(recursive: true));

  for (final (name, hasV2, url) in [
    ('v1_download_unicode', false, '$_v1/tasks/12827/attachments/215'),
    ('v2_download_unicode', true, '$_v2/tasks/12828/attachments/218'),
  ]) {
    test('$name: the original lands in the target, named by the caller, '
        'the directories created', () async {
      final dio = fakeDio({url: _captured(name)});

      await _attachments(
        dio,
        hasV2: hasV2,
      ).download(hasV2 ? 12828 : 12827, hasV2 ? 218 : 215, target: target);

      expect(target.readAsStringSync(), _text);
      expect(part().existsSync(), isFalse);
      expect(temp.listSync(recursive: true).whereType<File>(), hasLength(1));
      final request = adapterOf(dio).requests.single;
      expect(request.method, 'GET');
      expect(request.headers['Accept'], '*/*');
      expect(request.headers.containsKey('Range'), isFalse);
    });
  }

  test('binary bodies arrive byte for byte', () async {
    final random = Random(26);
    final bytes = Uint8List.fromList([
      for (var i = 0; i < 300 * 1024; i++) random.nextInt(256),
    ]);
    final dio = fakeDio({'$_v2/tasks/1/attachments/2': _bytes(bytes)});

    await _attachments(dio).download(1, 2, target: target);

    expect(target.readAsBytesSync(), bytes);
  });

  test('replaces a target that is there already', () async {
    target
      ..createSync(recursive: true)
      ..writeAsStringSync('an older copy that is longer than the new one');
    final dio = fakeDio({
      '$_v2/tasks/1/attachments/2': _bytes([1, 2, 3]),
    });

    await _attachments(dio).download(1, 2, target: target);

    expect(target.readAsBytesSync(), [1, 2, 3]);
  });

  test('a part left behind is resumed with a range request', () async {
    part()
      ..createSync(recursive: true)
      ..writeAsStringSync(_text.substring(0, 11));
    final dio = fakeDio({
      '$_v2/tasks/12828/attachments/218': _captured('v2_download_range'),
    });

    await _attachments(dio).download(12828, 218, target: target);

    expect(adapterOf(dio).requests.single.headers['Range'], 'bytes=11-');
    expect(target.readAsStringSync(), _text);
    expect(part().existsSync(), isFalse);
  });

  test('a part is replaced when the server answers in full', () async {
    part()
      ..createSync(recursive: true)
      ..writeAsStringSync('stale part');
    final dio = fakeDio({
      '$_v2/tasks/12828/attachments/218': _captured('v2_download_unicode'),
    });

    await _attachments(dio).download(12828, 218, target: target);

    expect(adapterOf(dio).requests.single.headers['Range'], 'bytes=10-');
    expect(target.readAsStringSync(), _text);
  });

  test('a part the range does not fit (416) is dropped and the file read '
      'again in full', () async {
    part()
      ..createSync(recursive: true)
      ..writeAsStringSync('${_text}and more');
    final dio = fakeDio({
      '$_v2/tasks/12828/attachments/218': sequence([
        status(416),
        _captured('v2_download_unicode'),
      ]),
    });

    await _attachments(dio).download(12828, 218, target: target);

    expect(adapterOf(dio).requests.map((request) => request.headers['Range']), [
      'bytes=33-',
      null,
    ]);
    expect(target.readAsStringSync(), _text);
  });

  test('a range other than the one asked for is refused and the part '
      'dropped', () async {
    part()
      ..createSync(recursive: true)
      ..writeAsStringSync(_text.substring(0, 5));
    final dio = fakeDio({
      '$_v2/tasks/12828/attachments/218': _captured('v2_download_range'),
    });

    await expectLater(
      _attachments(dio).download(12828, 218, target: target),
      throwsA(isA<UnexpectedResponse>()),
    );
    expect(part().existsSync(), isFalse);
    expect(target.existsSync(), isFalse);
  });

  for (final (name, hasV2, url) in [
    ('v1_download_unknown', false, '$_v1/tasks/12827/attachments/999999'),
    ('v2_download_unknown', true, '$_v2/tasks/12828/attachments/999999'),
  ]) {
    test('$name: a missing attachment is NotFound 4011', () async {
      final dio = fakeDio({url: _captured(name)});

      await expectLater(
        _attachments(
          dio,
          hasV2: hasV2,
        ).download(hasV2 ? 12828 : 12827, 999999, target: target),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 4011)),
      );
      expect(target.existsSync(), isFalse);
    });
  }

  test('a foreign attachment is Forbidden', () async {
    final dio = fakeDio({
      '$_v2/tasks/1/attachments/2': errorFixture('v2_403_project_2.7.0'),
    });

    await expectLater(
      _attachments(dio).download(1, 2, target: target),
      throwsA(isA<Forbidden>()),
    );
  });

  test('a body that breaks off is a network failure and keeps the part for '
      'the next attempt', () async {
    final dio = fakeDio({
      '$_v2/tasks/1/attachments/2': _brokenOff(
        utf8.encode('first half'),
        declared: 20,
      ),
    });

    await expectLater(
      _attachments(dio).download(1, 2, target: target),
      throwsA(isA<NetworkFailure>()),
    );
    expect(target.existsSync(), isFalse);
    expect(part().readAsStringSync(), 'first half');
  });

  test("the caller's cancel stops the download and keeps the part", () async {
    final sent = Completer<void>();
    final dio = fakeDio({
      '$_v2/tasks/1/attachments/2': _stalling(utf8.encode('head'), sent: sent),
    });
    final cancel = CancelToken();

    final download = _attachments(dio)
        .download(1, 2, target: target, cancel: cancel);
    await sent.future;
    await pumpEventQueue();
    cancel.cancel();

    await expectLater(
      download,
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
    expect(target.existsSync(), isFalse);
    expect(part().readAsStringSync(), 'head');
  });

  test("a failed write to disk is rethrown as it is, the caller's token "
      'left alone', () async {
    Directory(part().path).createSync(recursive: true);
    final dio = fakeDio({
      '$_v2/tasks/1/attachments/2': _bytes([1, 2, 3]),
    });
    final cancel = CancelToken();

    await expectLater(
      _attachments(dio).download(1, 2, target: target, cancel: cancel),
      throwsA(isA<FileSystemException>()),
    );
    expect(cancel.isCancelled, isFalse);
  });
}
