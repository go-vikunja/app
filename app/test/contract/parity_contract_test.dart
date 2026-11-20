@Tags(['contract'])
@Timeout(Duration(minutes: 10))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../parity/backends.dart';
import '../parity/rules.dart';
import '../parity/scenarios.dart';
import 'helpers.dart';

// The same scenarios and rule probes against the unit tests' fakes and
// against the local test server, so a fake that drifts from the server
// shows. The fakes' group needs no server and runs with every other test
// (tool/ci/test.sh runs all tags); the server's needs VIKUNJA_CONTRACT=1.
void main() {
  group('against the fakes', () {
    late FakeBackend backend;
    setUp(() => backend = FakeBackend());

    parityScenarios(() => backend);
    parityRules(() => backend);
  });

  group('against the local Docker server', skip: contractSkip, () {
    late Dio dio;
    late ServerConnection connection;

    setUpAll(() async {
      dio = contractDio();
      connection = await DioServerConnector(dio)
          .connect('http://localhost:$contractServerPort');
    });

    tearDownAll(() => dio.close(force: true));

    for (final version in contractApiVersions) {
      group('over ${version.pathSegment}', () {
        late ServerBackend backend;
        // One user per version: /register and /login share a rate limit.
        setUpAll(
          () async =>
              backend = await ServerBackend.register(dio, connection, version),
        );

        parityScenarios(() => backend);
        parityRules(() => backend);
      });
    }
  });
}
