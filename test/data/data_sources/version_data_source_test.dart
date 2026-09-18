import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vikunja_app/data/data_sources/version_data_source.dart';

import '../../helpers/mock_http_overrides.dart';

void main() {
  late VersionDataSource datasource;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    datasource = VersionDataSource();
  });

  group('getLatestVersionTag', () {
    test('returns the newest release tag with the v prefix stripped', () async {
      installMockHttpClient(
        (_, _, _) => http.Response(
          jsonEncode([
            {'tag_name': 'v0.2.0'},
            {'tag_name': 'v0.1.0'},
          ]),
          200,
        ),
      );

      expect(await datasource.getLatestVersionTag(), '0.2.0');
    });

    test('leaves a tag without a v prefix alone', () async {
      installMockHttpClient(
        (_, _, _) => http.Response(
          jsonEncode([
            {'tag_name': '0.3.0'},
          ]),
          200,
        ),
      );

      expect(await datasource.getLatestVersionTag(), '0.3.0');
    });

    test('queries the go-vikunja releases endpoint', () async {
      final client = installMockHttpClient(
        (_, _, _) => http.Response(
          jsonEncode([
            {'tag_name': 'v1.0.0'},
          ]),
          200,
        ),
      );

      await datasource.getLatestVersionTag();

      expect(
        client.requests.single.url.toString(),
        'https://api.github.com/repos/go-vikunja/app/releases',
      );
      expect(client.requests.single.method, 'GET');
    });

    test('returns null when the newest release has no tag', () async {
      installMockHttpClient(
        (_, _, _) => http.Response(
          jsonEncode([
            {'name': 'untagged'},
          ]),
          200,
        ),
      );

      expect(await datasource.getLatestVersionTag(), isNull);
    });

    test('returns null when the response is not a list', () async {
      installMockHttpClient(
        (_, _, _) => http.Response('{"message":"rate limited"}', 403),
      );

      expect(await datasource.getLatestVersionTag(), isNull);
    });
  });

  group('getCurrentVersionTag', () {
    test('joins the version and build number with a plus', () async {
      PackageInfo.setMockInitialValues(
        appName: 'Vikunja',
        packageName: 'io.vikunja.app',
        version: '0.1.8',
        buildNumber: '42',
        buildSignature: '',
      );

      expect(await datasource.getCurrentVersionTag(), '0.1.8+42');
    });

    test('omits the plus when there is no build number', () async {
      PackageInfo.setMockInitialValues(
        appName: 'Vikunja',
        packageName: 'io.vikunja.app',
        version: '0.1.8',
        buildNumber: '',
        buildSignature: '',
      );

      expect(await datasource.getCurrentVersionTag(), '0.1.8');
    });
  });
}
