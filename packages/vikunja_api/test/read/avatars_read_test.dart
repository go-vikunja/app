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

// The start of a PNG, enough for the client, which never decodes.
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

// The initials provider's answer on 2.7.0.
const _svg = '<svg viewBox="0 0 100 100"><text>A</text></svg>';

AvatarsPort _avatars(Dio dio, {bool hasV2 = true}) => createReadClient(
  dio: dio,
  connection: testConnection(hasV2: hasV2),
).avatars;

FakeRoute _image(List<int> bytes, String? contentType) =>
    (_) => ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        if (contentType != null) Headers.contentTypeHeader: [contentType],
      },
    );

void main() {
  for (final (hasV2, base) in [(true, _v2), (false, _v1)]) {
    group(hasV2 ? 'v2' : 'v1', () {
      test('the bytes and the media type of the answer', () async {
        final dio = fakeDio({
          '$base/avatar/alice?size=64': _image(_png, 'image/png'),
        });

        final avatar = await _avatars(
          dio,
          hasV2: hasV2,
        ).fetch('alice', size: 64);

        expect(avatar.bytes, _png);
        expect(avatar.contentType, 'image/png');
        expect(avatar.isSvg, isFalse);
        final request = adapterOf(dio).requests.single;
        expect(request.method, 'GET');
        expect(request.headers['Accept'], 'image/*');
        expect(request.responseType, ResponseType.bytes);
      });

      test('an SVG, the media type without its parameters', () async {
        final dio = fakeDio({
          '$base/avatar/alice?size=50': _image(
            utf8.encode(_svg),
            'Image/SVG+XML; charset=utf-8',
          ),
        });

        final avatar = await _avatars(
          dio,
          hasV2: hasV2,
        ).fetch('alice', size: 50);

        expect(avatar.contentType, 'image/svg+xml');
        expect(avatar.isSvg, isTrue);
        expect(utf8.decode(avatar.bytes), _svg);
      });

      test('the username is one path segment', () async {
        final dio = fakeDio({
          '$base/avatar/a%20b%2Fc%40example.com?size=32': _image(
            _png,
            'image/jpeg',
          ),
        });

        final avatar = await _avatars(
          dio,
          hasV2: hasV2,
        ).fetch('a b/c@example.com', size: 32);

        expect(avatar.contentType, 'image/jpeg');
      });

      test('octet-stream is passed on for the caller to decode', () async {
        final dio = fakeDio({
          '$base/avatar/alice?size=64': _image(
            _png,
            'application/octet-stream',
          ),
        });

        final avatar = await _avatars(
          dio,
          hasV2: hasV2,
        ).fetch('alice', size: 64);

        expect(avatar.contentType, 'application/octet-stream');
        expect(avatar.isSvg, isFalse);
      });

      group('answers that are not an image are unexpected', () {
        final cases = <String, FakeRoute>{
          'an HTML page': html('<html>Sign in</html>'),
          'JSON': json({'message': 'ok'}),
          'no media type': _image(_png, null),
          'an empty image': _image(const [], 'image/png'),
        };
        for (final MapEntry(key: name, value: route) in cases.entries) {
          test(name, () async {
            final dio = fakeDio({'$base/avatar/alice?size=64': route});

            await expectLater(
              _avatars(dio, hasV2: hasV2).fetch('alice', size: 64),
              throwsA(
                isA<UnexpectedResponse>().having(
                  (f) => f.statusCode,
                  'statusCode',
                  200,
                ),
              ),
            );
          });
        }
      });

      test('errors are normalized like every other read', () async {
        final dio = fakeDio({
          '$base/avatar/missing?size=64': errorFixture(
            'v1_401_code11_missing_2.7.0',
          ),
          '$base/avatar/broken?size=64': json({
            'message': 'Internal Server Error',
          }, status: 500),
        });
        final avatars = _avatars(dio, hasV2: hasV2);

        await expectLater(
          avatars.fetch('missing', size: 64),
          throwsA(isA<TokenRejected>()),
        );
        await expectLater(
          avatars.fetch('broken', size: 64),
          throwsA(isA<ServerFailure>()),
        );
      });

      test('network failures are normalized', () async {
        await expectLater(
          _avatars(fakeDio({}), hasV2: hasV2).fetch('alice', size: 64),
          throwsA(isA<NetworkFailure>()),
        );
      });

      test('a cancelled request rethrows its DioException', () async {
        final dio = fakeDio({
          '$base/avatar/alice?size=64': failsWith(
            (request) => DioException.requestCancelled(
              requestOptions: request,
              reason: 'closed',
            ),
          ),
        });

        await expectLater(
          _avatars(dio, hasV2: hasV2).fetch('alice', size: 64),
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

  test('a v2 validation problem for a bad size', () async {
    final dio = fakeDio({
      '$_v2/avatar/alice?size=0': (_) => ResponseBody.fromString(
        jsonEncode({
          'title': 'Unprocessable Entity',
          'status': 422,
          'detail': 'validation failed',
          'errors': [
            {
              'message': 'expected number >= 1',
              'location': 'query.size',
              'value': 0,
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
      _avatars(dio).fetch('alice', size: 0),
      throwsA(isA<ValidationFailed>()),
    );
  });
}
