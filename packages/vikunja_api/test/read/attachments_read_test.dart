import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';

const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';

final _png = Uint8List.fromList([
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
]);

AttachmentsPort _attachments(Dio dio, {bool hasV2 = true}) => createReadClient(
  dio: dio,
  connection: testConnection(hasV2: hasV2),
).attachments;

FakeRoute _file(
  List<int> bytes,
  String? contentType, {
  int status = 200,
  bool withLength = true,
}) =>
    (_) => ResponseBody.fromBytes(
      bytes,
      status,
      headers: {
        if (contentType != null) Headers.contentTypeHeader: [contentType],
        if (withLength) Headers.contentLengthHeader: ['${bytes.length}'],
      },
    );

/// Chunks of [chunkSize] bytes until [total], counting what was sent, so
/// a test sees that the client stopped early.
final class _Endless {
  new({required this.total, this.declared, this.status = 200});

  static const int chunkSize = 1024 * 1024;

  final int total;
  final int? declared;
  final int status;
  int sent = 0;
  bool cancelled = false;

  ResponseBody call(RequestOptions request) {
    late final StreamController<Uint8List> controller;
    controller = StreamController<Uint8List>(
      onListen: () async {
        while (sent < total && !cancelled) {
          await Future<void>.delayed(Duration.zero);
          if (cancelled) break;
          controller.add(Uint8List(chunkSize));
          sent += chunkSize;
        }
        await controller.close();
      },
      onCancel: () => cancelled = true,
    );
    return ResponseBody(
      controller.stream,
      status,
      headers: {
        Headers.contentTypeHeader: ['image/png'],
        if (declared != null) Headers.contentLengthHeader: ['$declared'],
      },
    );
  }
}

void main() {
  for (final (hasV2, base) in [(true, _v2), (false, _v1)]) {
    group(hasV2 ? 'v2' : 'v1', () {
      test('the original, any media type accepted', () async {
        final dio = fakeDio({
          '$base/tasks/17/attachments/14': _file(_png, 'image/png'),
        });

        final blob = await _attachments(dio, hasV2: hasV2).fetch(17, 14);

        expect(blob.bytes, _png);
        expect(blob.contentType, 'image/png');
        expect(blob.isSvg, isFalse);
        final request = adapterOf(dio).requests.single;
        expect(request.method, 'GET');
        expect(request.headers['Accept'], '*/*');
      });

      test('a preview by its wire size, images accepted', () async {
        final dio = fakeDio({
          for (final size in AttachmentPreviewSize.values)
            '$base/tasks/17/attachments/14?preview_size=${size.wireName}':
                _file(_png, 'image/png'),
        });
        final attachments = _attachments(dio, hasV2: hasV2);

        for (final size in AttachmentPreviewSize.values) {
          final blob = await attachments.fetch(17, 14, preview: size);
          expect(blob.contentType, 'image/png');
        }
        expect(adapterOf(dio).requests.map((r) => r.uri.query), [
          'preview_size=sm',
          'preview_size=md',
          'preview_size=lg',
          'preview_size=xl',
        ]);
        expect(
          adapterOf(dio).requests.map((r) => r.headers['Accept']).toSet(),
          {'image/*'},
        );
      });

      test('what the server cannot preview comes back as it is', () async {
        const svg = '<svg><script>alert(1)</script></svg>';
        final dio = fakeDio({
          '$base/tasks/17/attachments/15?preview_size=md': _file(
            utf8.encode('just some text'),
            'text/plain; charset=utf-8',
          ),
          '$base/tasks/17/attachments/16?preview_size=md': _file(
            utf8.encode(svg),
            'Image/SVG+XML',
          ),
          '$base/tasks/17/attachments/18': _file(utf8.encode('x'), null),
        });
        final attachments = _attachments(dio, hasV2: hasV2);

        final text = await attachments.fetch(
          17,
          15,
          preview: AttachmentPreviewSize.medium,
        );
        final vector = await attachments.fetch(
          17,
          16,
          preview: AttachmentPreviewSize.medium,
        );
        final untyped = await attachments.fetch(17, 18);

        expect(text.contentType, 'text/plain');
        expect(utf8.decode(text.bytes), 'just some text');
        expect(vector.contentType, 'image/svg+xml');
        expect(vector.isSvg, isTrue);
        expect(untyped.contentType, 'application/octet-stream');
      });

      test('an empty file is a file', () async {
        final dio = fakeDio({
          '$base/tasks/17/attachments/19': _file(const [], 'text/plain'),
        });

        final blob = await _attachments(dio, hasV2: hasV2).fetch(17, 19);

        expect(blob.bytes, isEmpty);
      });

      group('bodies above 25 MB are refused', () {
        test('by their Content-Length, before reading', () async {
          final endless = _Endless(
            total: 64 * 1024 * 1024,
            declared: maxAttachmentBytes + 1,
          );
          final dio = fakeDio({'$base/tasks/17/attachments/14': endless.call});

          await expectLater(
            _attachments(dio, hasV2: hasV2).fetch(17, 14),
            throwsA(isA<UnexpectedResponse>()),
          );
          // The cancel reaches the source a moment later.
          await pumpEventQueue();
          expect(endless.sent, lessThan(8 * _Endless.chunkSize));
          expect(endless.cancelled, isTrue);
        });

        test('by what arrives, without a Content-Length', () async {
          final endless = _Endless(total: 64 * 1024 * 1024);
          final dio = fakeDio({'$base/tasks/17/attachments/14': endless.call});

          await expectLater(
            _attachments(dio, hasV2: hasV2).fetch(17, 14),
            throwsA(isA<UnexpectedResponse>()),
          );
          await pumpEventQueue();
          expect(endless.sent, lessThan(30 * 1024 * 1024));
          expect(endless.cancelled, isTrue);
        });

        test('by what arrives, despite a smaller Content-Length', () async {
          final endless = _Endless(total: 64 * 1024 * 1024, declared: 100);
          final dio = fakeDio({'$base/tasks/17/attachments/14': endless.call});

          await expectLater(
            _attachments(dio, hasV2: hasV2).fetch(17, 14),
            throwsA(isA<UnexpectedResponse>()),
          );
        });

        test('exactly 25 MB passes', () async {
          final endless = _Endless(total: maxAttachmentBytes);
          final dio = fakeDio({'$base/tasks/17/attachments/14': endless.call});

          final blob = await _attachments(dio, hasV2: hasV2).fetch(17, 14);

          expect(blob.bytes.length, maxAttachmentBytes);
        });
      });

      test('errors keep their codes although the body streams', () async {
        final dio = fakeDio({
          '$base/tasks/17/attachments/99': json({
            'code': 4011,
            'message': 'This task attachment does not exist.',
          }, status: 404),
          '$base/tasks/21/attachments/22': json({
            'code': 1,
            'message': "You're not allowed to do this.",
          }, status: 403),
          '$base/tasks/17/attachments/98': errorFixture(
            'v1_401_code11_missing_2.7.0',
          ),
          '$base/tasks/17/attachments/97': json({
            'message': 'Internal Server Error',
          }, status: 500),
        });
        final attachments = _attachments(dio, hasV2: hasV2);

        await expectLater(
          attachments.fetch(17, 99),
          throwsA(isA<NotFound>().having((f) => f.code, 'code', 4011)),
        );
        await expectLater(attachments.fetch(21, 22), throwsA(isA<Forbidden>()));
        await expectLater(
          attachments.fetch(17, 98),
          throwsA(isA<TokenRejected>()),
        );
        await expectLater(
          attachments.fetch(17, 97),
          throwsA(isA<ServerFailure>()),
        );
      });

      test('an endless error body stops downloading after its cap', () async {
        final endless = _Endless(total: 64 * 1024 * 1024, status: 500);
        final dio = fakeDio({'$base/tasks/17/attachments/14': endless.call});

        await expectLater(
          _attachments(dio, hasV2: hasV2).fetch(17, 14),
          throwsA(isA<ServerFailure>()),
        );
        await pumpEventQueue();
        expect(endless.sent, lessThan(8 * _Endless.chunkSize));
        expect(endless.cancelled, isTrue);
      });

      test('network failures are normalized, cancellations rethrown', () async {
        await expectLater(
          _attachments(fakeDio({}), hasV2: hasV2).fetch(17, 14),
          throwsA(isA<NetworkFailure>()),
        );
        final dio = fakeDio({
          '$base/tasks/17/attachments/14': failsWith(
            (request) => DioException.requestCancelled(
              requestOptions: request,
              reason: 'closed',
            ),
          ),
        });
        await expectLater(
          _attachments(dio, hasV2: hasV2).fetch(17, 14),
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
  }

  test(
    'v2 rejects an unknown preview size with a validation problem',
    () async {
      final dio = fakeDio({
        '$_v2/tasks/17/attachments/14?preview_size=sm': (_) =>
            ResponseBody.fromString(
              jsonEncode({
                'title': 'Unprocessable Entity',
                'status': 422,
                'detail': 'validation failed',
                'errors': [
                  {
                    'message': 'expected value to be one of "sm, md, lg, xl"',
                    'location': 'query.preview_size',
                    'value': 'foo',
                  },
                ],
              }),
              422,
              headers: {
                Headers.contentTypeHeader: ['application/problem+json'],
              },
            ),
      });

      await expectLater(
        _attachments(dio).fetch(17, 14, preview: AttachmentPreviewSize.small),
        throwsA(isA<ValidationFailed>()),
      );
    },
  );
}
