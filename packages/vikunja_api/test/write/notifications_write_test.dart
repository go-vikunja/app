import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';

const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';

NotificationsWritePort _notifications(Dio dio, {bool hasV2 = true}) =>
    createWriteClient(
      dio: dio,
      connection: testConnection(hasV2: hasV2),
    ).notifications;

String _call(Dio dio) {
  final request = adapterOf(dio).requests.single;
  return '${request.method} ${request.uri}';
}

// The 200 answers and the 403 for an unknown id were captured from 2.7.0
// by tool/capture_notification_fixtures.dart.
void main() {
  group('markRead', () {
    test('v2 puts the read state', () async {
      final dio = fakeDio({
        '$_v2/notifications/373': capturedFixture(
          'write/v2_notification_mark_read_2.7.0',
        ),
      });

      await _notifications(dio).markRead(373);

      expect(_call(dio), 'PUT $_v2/notifications/373');
      expect(adapterOf(dio).decodedBodies.single, {'read': true});
      expect(
        adapterOf(dio).requests.single.headers['Accept'],
        'application/json',
      );
    });

    test('v1 posts the read state', () async {
      final dio = fakeDio({
        '$_v1/notifications/372': capturedFixture(
          'write/v1_notification_mark_read_2.7.0',
        ),
      });

      await _notifications(dio, hasV2: false).markRead(372);

      expect(_call(dio), 'POST $_v1/notifications/372');
      expect(adapterOf(dio).decodedBodies.single, {'read': true});
    });

    for (final (hasV2, method, base) in [
      (true, 'PUT', _v2),
      (false, 'POST', _v1),
    ]) {
      test('${hasV2 ? 'v2' : 'v1'} marks unread with read false', () async {
        final dio = fakeDio({
          '$base/notifications/373': capturedFixture(
            'write/v2_notification_mark_unread_2.7.0',
          ),
        });

        await _notifications(dio, hasV2: hasV2).markRead(373, read: false);

        expect(_call(dio), '$method $base/notifications/373');
        expect(adapterOf(dio).decodedBodies.single, {'read': false});
      });

      test('${hasV2 ? 'v2' : 'v1'}: a notification that is gone counts as '
          'done', () async {
        final dio = fakeDio({
          '$base/notifications/999999999': capturedFixture(
            'write/${hasV2 ? 'v2' : 'v1'}_notification_mark_unknown_2.7.0',
          ),
          // 2.7.0 never answers so; a 404 with any Vikunja code is a
          // missing record rather than a missing route.
          '$base/notifications/5': json({
            'code': 9001,
            'message': 'Not found.',
          }, status: 404),
        });
        final notifications = _notifications(dio, hasV2: hasV2);

        await expectLater(notifications.markRead(999999999), completes);
        await expectLater(notifications.markRead(5), completes);
      });
    }

    test('an absent route is a failure', () async {
      final dio = fakeDio({
        '$_v2/notifications/1': errorFixture('v2_404_route_2.7.0'),
      });

      await expectLater(
        _notifications(dio).markRead(1),
        throwsA(
          isA<NotFound>().having((f) => f.routeAbsent, 'routeAbsent', isTrue),
        ),
      );
    });

    test('other errors are normalized', () async {
      final dio = fakeDio({
        '$_v2/notifications/1': errorFixture('v2_401_code11_missing_2.7.0'),
        '$_v1/notifications/1': errorFixture('v1_401_code11_missing_2.7.0'),
        '$_v2/notifications/2': json({'message': 'boom'}, status: 500),
      });

      await expectLater(
        _notifications(dio).markRead(1),
        throwsA(isA<TokenRejected>()),
      );
      await expectLater(
        _notifications(dio, hasV2: false).markRead(1),
        throwsA(isA<TokenRejected>()),
      );
      await expectLater(
        _notifications(dio).markRead(2),
        throwsA(
          isA<ServerFailure>().having((f) => f.statusCode, 'status', 500),
        ),
      );
      await expectLater(
        _notifications(fakeDio({})).markRead(1),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('a cancelled request rethrows its DioException', () async {
      final dio = fakeDio({
        '$_v2/notifications/1': failsWith(
          (request) => DioException.requestCancelled(
            requestOptions: request,
            reason: 'closed',
          ),
        ),
      });

      await expectLater(
        _notifications(dio).markRead(1),
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

  group('markAllRead', () {
    for (final (hasV2, base) in [(true, _v2), (false, _v1)]) {
      final version = hasV2 ? 'v2' : 'v1';

      test('$version posts without a body', () async {
        final dio = fakeDio({
          '$base/notifications': capturedFixture(
            'write/${version}_notifications_mark_all_2.7.0',
          ),
        });

        await _notifications(dio, hasV2: hasV2).markAllRead();

        expect(_call(dio), 'POST $base/notifications');
        expect(adapterOf(dio).requestBodies.single, isNull);
      });
    }

    // Link shares get a 403 here; it is not swallowed like markRead's.
    test('errors are normalized', () async {
      final dio = fakeDio({
        '$_v2/notifications': errorFixture('v2_401_code11_missing_2.7.0'),
        '$_v1/notifications': json({
          'code': 0,
          'message': 'Forbidden',
        }, status: 403),
      });

      await expectLater(
        _notifications(dio).markAllRead(),
        throwsA(isA<TokenRejected>()),
      );
      await expectLater(
        _notifications(dio, hasV2: false).markAllRead(),
        throwsA(isA<Forbidden>()),
      );
      await expectLater(
        _notifications(fakeDio({})).markAllRead(),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
