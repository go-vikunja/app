/// Complements `client_test.dart`, which owns auth headers and token refresh.
/// This file owns the parts that flow *around* auth: base-URL normalisation,
/// the four verb helpers, and how a raw http response becomes a [Response].
library;

import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';

class _StubSettings implements SettingsDatasource {
  @override
  Future<String?> getUserToken() async => null;
  @override
  Future<String?> getRefreshToken() async => null;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestableClient extends Client {
  _TestableClient({required super.base, required this.mockHttpClient});

  final http.Client mockHttpClient;

  @override
  http.Client createClient() => mockHttpClient;
}

/// Builds a client whose transport always answers with [respond], and records
/// the request it saw.
({_TestableClient client, List<http.Request> requests}) clientThatReturns(
  http.Response Function(http.Request request) respond, {
  String base = 'https://vikunja.example.com',
}) {
  final requests = <http.Request>[];
  final mock = http_testing.MockClient((request) async {
    requests.add(request);
    return respond(request);
  });
  final client = _TestableClient(base: base, mockHttpClient: mock)
    ..settingsDatasource = _StubSettings();
  return (client: client, requests: requests);
}

http.Response jsonResponse(Object? body, {int status = 200}) =>
    http.Response(jsonEncode(body), status, headers: {'x-page': '1'});

void main() {
  group('Client base url normalisation', () {
    test('keeps a plain host and appends the api prefix', () {
      expect(
        Client(base: 'https://vikunja.example.com').apiBase,
        'https://vikunja.example.com/api/v1',
      );
    });

    test('strips spaces anywhere in the address', () {
      expect(
        Client(base: ' https://vikunja. example.com ').apiBase,
        'https://vikunja.example.com/api/v1',
      );
    });

    test('strips a single trailing slash', () {
      expect(
        Client(base: 'https://vikunja.example.com/').apiBase,
        'https://vikunja.example.com/api/v1',
      );
    });

    test('does not double up an address that already ends in /api/v1', () {
      expect(
        Client(base: 'https://vikunja.example.com/api/v1').apiBase,
        'https://vikunja.example.com/api/v1',
      );
    });

    test('handles a trailing slash after the api prefix', () {
      expect(
        Client(base: 'https://vikunja.example.com/api/v1/').apiBase,
        'https://vikunja.example.com/api/v1',
      );
    });

    test('an empty address still produces a parseable api base', () {
      expect(Client(base: '').apiBase, '/api/v1');
    });
  });

  group('Client verbs', () {
    test('get requests the api path and maps the body', () async {
      final setup = clientThatReturns((_) => jsonResponse({'id': 7}));

      final response = await setup.client.get<int>(
        url: '/tasks/7',
        mapper: (body) => body['id'] as int,
      );

      expect(setup.requests.single.method, 'GET');
      expect(setup.requests.single.url.host, 'vikunja.example.com');
      expect(setup.requests.single.url.path, '/api/v1/tasks/7');
      expect(response.toSuccess().body, 7);
    });

    test('get appends query parameters', () async {
      final setup = clientThatReturns((_) => jsonResponse([]));

      await setup.client.get<List<dynamic>>(
        url: '/tasks',
        mapper: (body) => body as List<dynamic>,
        queryParameters: {
          'page': ['2'],
          'sort_by': ['due_date', 'id'],
        },
      );

      final query = setup.requests.single.url.queryParametersAll;
      expect(query['page'], ['2']);
      expect(query['sort_by'], ['due_date', 'id']);
    });

    test('post sends a json-encoded body', () async {
      final setup = clientThatReturns((_) => jsonResponse({'ok': true}));

      await setup.client.post<bool>(
        url: '/tasks/1',
        body: {'title': 'new title'},
        mapper: (body) => body['ok'] as bool,
      );

      expect(setup.requests.single.method, 'POST');
      expect(jsonDecode(setup.requests.single.body), {'title': 'new title'});
    });

    test('put sends a json-encoded body', () async {
      final setup = clientThatReturns((_) => jsonResponse({'id': 1}));

      await setup.client.put<int>(
        url: '/projects',
        body: {'title': 'Project'},
        mapper: (body) => body['id'] as int,
      );

      expect(setup.requests.single.method, 'PUT');
      expect(jsonDecode(setup.requests.single.body), {'title': 'Project'});
    });

    test('delete targets the api path', () async {
      final setup = clientThatReturns((_) => http.Response('', 204));

      final response = await setup.client.delete<Object>(url: '/tasks/9');

      expect(setup.requests.single.method, 'DELETE');
      expect(setup.requests.single.url.path, '/api/v1/tasks/9');
      expect(response.isSuccessful, isTrue);
    });
  });

  group('Client response handling', () {
    test('returns a VoidResponse when no mapper is supplied', () async {
      final setup = clientThatReturns((_) => jsonResponse({'ignored': true}));

      final response = await setup.client.get<Object>(url: '/info');

      expect(response, isA<VoidResponse<Object>>());
    });

    test('maps a literal null body to an empty list', () async {
      // The backend returns the string "null" instead of [] for empty lists.
      final setup = clientThatReturns((_) => http.Response('null', 200));

      final response = await setup.client.get<List<dynamic>>(
        url: '/labels',
        mapper: (body) => body as List<dynamic>,
      );

      expect(response.toSuccess().body, isEmpty);
    });

    test('propagates response headers on success', () async {
      final setup = clientThatReturns(
        (_) => http.Response(
          '{}',
          200,
          headers: {'x-pagination-total-pages': '4'},
        ),
      );

      final response = await setup.client.get<Map<String, dynamic>>(
        url: '/projects',
        mapper: (body) => body as Map<String, dynamic>,
      );

      expect(response.toSuccess().headers['x-pagination-total-pages'], '4');
    });

    test('turns a 4xx json body into an ErrorResponse', () async {
      final setup = clientThatReturns(
        (_) =>
            jsonResponse({'message': 'not found', 'code': 4004}, status: 404),
      );

      final response = await setup.client.get<Object>(
        url: '/tasks/404',
        mapper: (body) => body as Object,
      );

      expect(response.toError().statusCode, 404);
      expect(response.toError().error['code'], 4004);
    });

    test('turns a 5xx json body into an ErrorResponse', () async {
      final setup = clientThatReturns(
        (_) => jsonResponse({'message': 'server exploded'}, status: 500),
      );

      final response = await setup.client.get<Object>(
        url: '/tasks',
        mapper: (body) => body as Object,
      );

      expect(response.toError().statusCode, 500);
    });

    test('turns an unparseable error body into an ExceptionResponse', () async {
      final setup = clientThatReturns(
        (_) => http.Response('<html>502 Bad Gateway</html>', 502),
      );

      final response = await setup.client.get<Object>(
        url: '/tasks',
        mapper: (body) => body as Object,
      );

      expect(response.isException, isTrue);
      expect(response.toException().exception, isA<FormatException>());
    });

    test(
      'turns an unencodable request body into an ExceptionResponse',
      () async {
        final setup = clientThatReturns((_) => jsonResponse({}));

        final response = await setup.client.post<Object>(
          url: '/tasks',
          body: Object(), // not JSON-encodable
          mapper: (body) => body as Object,
        );

        expect(response.isException, isTrue);
        expect(setup.requests, isEmpty);
      },
    );

    test('decodes utf-8 bodies', () async {
      final setup = clientThatReturns(
        (_) => http.Response.bytes(utf8.encode('{"title":"Grüße, 日本語"}'), 200),
      );

      final response = await setup.client.get<String>(
        url: '/tasks/1',
        mapper: (body) => body['title'] as String,
      );

      expect(response.toSuccess().body, 'Grüße, 日本語');
    });
  });

  group('Client.setIgnoreCerts', () {
    tearDown(() => io.HttpOverrides.global = null);

    test('records the flag and installs a matching http override', () {
      final client = Client(base: 'https://vikunja.example.com');

      client.setIgnoreCerts(true);

      expect(client.ignoreCertificates, isTrue);
      expect(io.HttpOverrides.current, isA<IgnoreCertHttpOverrides>());
      expect(
        (io.HttpOverrides.current as IgnoreCertHttpOverrides).ignoreCerts,
        isTrue,
      );
    });

    test('turning it back off reinstalls a permissive-off override', () {
      final client = Client(base: 'https://vikunja.example.com')
        ..setIgnoreCerts(true);

      client.setIgnoreCerts(false);

      expect(client.ignoreCertificates, isFalse);
      expect(
        (io.HttpOverrides.current as IgnoreCertHttpOverrides).ignoreCerts,
        isFalse,
      );
    });
  });

  group('IgnoreCertHttpOverrides', () {
    test('remembers the flag it was constructed with', () {
      expect(IgnoreCertHttpOverrides(true).ignoreCerts, isTrue);
      expect(IgnoreCertHttpOverrides(false).ignoreCerts, isFalse);
    });
  });
}
