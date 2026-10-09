import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

ServerConnection _connection(
  String root,
  Set<ApiVersion> apiVersions, {
  String version = 'v2.7.0',
}) {
  final info = ServerInfo(version: ServerVersion.tryParse(version));
  return ServerConnection(
    rootUri: Uri.parse(root),
    apiVersions: apiVersions,
    info: info,
    capabilities: ServerCapabilities.derive(
      info: info,
      apiVersions: apiVersions,
    ),
  );
}

void main() {
  group('ServerConnection.apiBaseUri', () {
    for (final (root, v1, v2) in [
      (
        'https://example.com',
        'https://example.com/api/v1',
        'https://example.com/api/v2',
      ),
      (
        'https://example.com/vikunja',
        'https://example.com/vikunja/api/v1',
        'https://example.com/vikunja/api/v2',
      ),
      (
        'https://example.com/apps/todo',
        'https://example.com/apps/todo/api/v1',
        'https://example.com/apps/todo/api/v2',
      ),
      (
        'http://192.168.1.10:3456/root',
        'http://192.168.1.10:3456/root/api/v1',
        'http://192.168.1.10:3456/root/api/v2',
      ),
      (
        'https://[::1]:3456',
        'https://[::1]:3456/api/v1',
        'https://[::1]:3456/api/v2',
      ),
    ]) {
      test(root, () {
        final connection = _connection(root, {ApiVersion.v1, ApiVersion.v2});
        expect(connection.apiBaseUri(ApiVersion.v1).toString(), v1);
        expect(connection.apiBaseUri(ApiVersion.v2).toString(), v2);
      });
    }
  });

  test('preferredApiVersion is v2 whenever it answered', () {
    expect(
      _connection('https://x', {
        ApiVersion.v1,
        ApiVersion.v2,
      }).preferredApiVersion,
      ApiVersion.v2,
    );
    expect(
      _connection('https://x', {ApiVersion.v2}).preferredApiVersion,
      ApiVersion.v2,
    );
    expect(
      _connection('https://x', {ApiVersion.v1}).preferredApiVersion,
      ApiVersion.v1,
    );
  });

  test('isInsecure only for plain http', () {
    expect(_connection('http://x', {ApiVersion.v1}).isInsecure, isTrue);
    expect(_connection('https://x', {ApiVersion.v1}).isInsecure, isFalse);
  });

  test('ApiVersion path segments', () {
    expect(ApiVersion.v1.pathSegment, 'v1');
    expect(ApiVersion.v2.pathSegment, 'v2');
  });

  group('apiV2Missing', () {
    test('a 2.4+ server answering only on v1 has v2 blocked', () {
      expect(_connection('https://x', {ApiVersion.v1}).apiV2Missing, isTrue);
      expect(
        _connection('https://x', {ApiVersion.v1}, version: 'dev').apiV2Missing,
        isTrue,
      );
    });

    test('servers that predate v2 or answer on v2 are not affected', () {
      expect(
        _connection('https://x', {
          ApiVersion.v1,
        }, version: 'v2.3.0').apiV2Missing,
        isFalse,
      );
      expect(
        _connection('https://x', {
          ApiVersion.v1,
        }, version: 'garbage').apiV2Missing,
        isFalse,
      );
      expect(
        _connection('https://x', {ApiVersion.v1, ApiVersion.v2}).apiV2Missing,
        isFalse,
      );
    });
  });
}
