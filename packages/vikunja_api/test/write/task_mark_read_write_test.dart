import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';

const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';

TasksWritePort _tasks(Dio dio, {bool hasV2 = true}) => createWriteClient(
  dio: dio,
  connection: testConnection(hasV2: hasV2),
).tasks;

FakeRoute _byMethod(String method, FakeRoute route) =>
    (request) => (request.method == method ? route : refused)(request);

void main() {
  test('v2 PUTs, the answer of 2.7.0', () async {
    final dio = fakeDio({
      '$_v2/tasks/17/read': _byMethod('PUT', json({'message': 'success'})),
    });

    await _tasks(dio).markRead(17);

    final request = adapterOf(dio).requests.single;
    expect(request.method, 'PUT');
    expect(adapterOf(dio).requestBodies.single, isNull);
  });

  test('v1 POSTs, the answer of 2.7.0', () async {
    final dio = fakeDio({
      '$_v1/tasks/17/read': _byMethod(
        'POST',
        json({'TaskID': 17, 'UserID': 0}),
      ),
    });

    await _tasks(dio, hasV2: false).markRead(17);

    expect(adapterOf(dio).requests.single.method, 'POST');
  });

  for (final (hasV2, base) in [(true, _v2), (false, _v1)]) {
    test('${hasV2 ? 'v2' : 'v1'}: failures are normalized', () async {
      final dio = fakeDio({
        '$base/tasks/17/read': errorFixture('v1_401_code11_missing_2.7.0'),
        '$base/tasks/18/read': json({'message': 'boom'}, status: 500),
      });
      final tasks = _tasks(dio, hasV2: hasV2);

      await expectLater(tasks.markRead(17), throwsA(isA<TokenRejected>()));
      await expectLater(tasks.markRead(18), throwsA(isA<ServerFailure>()));
      await expectLater(
        _tasks(fakeDio({}), hasV2: hasV2).markRead(17),
        throwsA(isA<NetworkFailure>()),
      );
    });
  }
}
