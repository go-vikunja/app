@Tags(['contract'])
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

void main() {
  late Dio dio;
  late ServerConnector connector;

  setUp(() {
    dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    connector = DioServerConnector(dio);
  });

  tearDown(() => dio.close(force: true));

  group('local Docker servers', skip: contractSkip, () {
    for (final (port, version, apiVersions, tier, concurrentWrites) in [
      (
        34527,
        contractServerVersion,
        {ApiVersion.v1, ApiVersion.v2},
        SupportTier.full,
        false,
      ),
    ]) {
      test('${version.display} on :$port', () async {
        final connection = await connector.connect('http://localhost:$port');

        expect(connection.rootUri, Uri.parse('http://localhost:$port'));
        expect(connection.isInsecure, isTrue);
        expect(connection.info.version, version);
        expect(connection.apiVersions, apiVersions);
        expect(connection.capabilities.tier, tier);
        expect(
          connection.info.frontendUrl,
          Uri.parse('http://localhost:$port/'),
        );
        expect(connection.info.maxFileSizeBytes, 20 * 1024 * 1024);
        expect(connection.info.concurrentWrites, concurrentWrites);
        expect(connection.info.auth.localEnabled, isTrue);
        expect(connection.capabilities.has(Capability.localAuth), isTrue);
        expect(
          connection.capabilities.has(Capability.apiV2),
          apiVersions.contains(ApiVersion.v2),
        );
      });
    }

    test('flags equal the raw /info body', () async {
      final connection = await connector.connect('http://localhost:34527');
      final raw = await dio.get<Map<String, Object?>>(
        'http://localhost:34527/api/v2/info',
      );
      final body = raw.data!;
      final info = connection.info;

      expect(info.version!.raw, body['version']);
      expect(info.linkSharingEnabled, body['link_sharing_enabled']);
      expect(info.taskAttachmentsEnabled, body['task_attachments_enabled']);
      expect(info.totpEnabled, body['totp_enabled']);
      expect(info.caldavEnabled, body['caldav_enabled']);
      expect(info.webhooksEnabled, body['webhooks_enabled']);
      expect(info.publicTeamsEnabled, body['public_teams_enabled']);
      expect(info.userDeletionEnabled, body['user_deletion_enabled']);
      expect(info.emailRemindersEnabled, body['email_reminders_enabled']);
      expect(info.maxItemsPerPage, body['max_items_per_page']);
      expect(info.maxFileSize, body['max_file_size']);
      expect(info.availableMigrators, body['available_migrators']);
      expect(
        info.enabledProFeatures,
        (body['enabled_pro_features']! as List).toSet(),
      );
      expect(info.concurrentWrites, body['concurrent_writes']);
      final legal = body['legal']! as Map<String, Object?>;
      if (info.version!.isAtLeast(2, 8)) {
        expect(legal['links'], isNotEmpty);
        expect([
          for (final link in info.legal.links)
            {'text': link.text, 'url': '${link.url}'},
        ], legal['links']);
      } else {
        // Before 2.8.0 /info has no links, and the test server sets neither
        // the imprint nor the privacy policy.
        expect(legal, isNot(contains('links')));
        expect(info.legal.links, isEmpty);
      }
      expect(info.legal.imprintUrl?.toString() ?? '', legal['imprint_url']);
      expect(
        info.legal.privacyPolicyUrl?.toString() ?? '',
        legal['privacy_policy_url'],
      );
    });

    test('the test server lists its terms as its one legal link', () async {
      final connection = await connector.connect('http://localhost:34527');
      if (!connection.info.version!.isAtLeast(2, 8)) {
        markTestSkipped('servers before 2.8.0 list no legal links');
        return;
      }
      final legal = connection.info.legal;

      expect(legal.links, [
        LegalLink(
          text: 'Terms of Service',
          url: Uri.parse('https://example.org/terms'),
        ),
      ]);
      expect(legal.imprintUrl, isNull);
      expect(legal.privacyPolicyUrl, isNull);
    });

    test('scheme-less input falls back to http after https fails', () async {
      final connection = await connector.connect('localhost:34527');

      expect(connection.rootUri, Uri.parse('http://localhost:34527'));
      expect(connection.isInsecure, isTrue);
      expect(connection.apiVersions, {ApiVersion.v1, ApiVersion.v2});
    });

    test(
      'an explicit https:// to a plain-http port is a TLS failure',
      () async {
        await expectLater(
          connector.connect('https://localhost:34527'),
          throwsA(
            isA<TlsFailure>().having(
              (f) => f.uri,
              'uri',
              Uri.parse('https://localhost:34527'),
            ),
          ),
        );
      },
    );

    test('a pasted API URL is normalised', () async {
      final connection = await connector.connect(
        'HTTP://LOCALHOST:34527/api/v1/',
      );

      expect(connection.rootUri, Uri.parse('http://localhost:34527'));
      expect(connection.apiVersions, {ApiVersion.v1, ApiVersion.v2});
    });

    for (final (input, root) in [
      ('localhost:34527/api/v1/info', 'http://localhost:34527'),
      ('http://localhost:34527/vikunja', 'http://localhost:34527'),
      ('http://localhost:34527/login', 'http://localhost:34527'),
      ('http://localhost:34527/projects/1/1', 'http://localhost:34527'),
      ('http://localhost:34527/tasks/by/upcoming', 'http://localhost:34527'),
    ]) {
      test('a pasted browser or API URL connects: $input', () async {
        final connection = await connector.connect(input);

        expect(connection.rootUri, Uri.parse(root));
      });
    }

    test('a closed port is unreachable', () async {
      await expectLater(
        connector.connect('http://localhost:34599'),
        throwsA(isA<ServerUnreachable>()),
      );
    });

    test('cancellation surfaces as a DioException', () async {
      final cancelToken = CancelToken();
      final connecting = connector.connect(
        'http://localhost:34527',
        cancelToken: cancelToken,
      );
      cancelToken.cancel();

      await expectLater(
        connecting,
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
