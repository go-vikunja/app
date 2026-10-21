import 'package:dio/dio.dart';
import 'package:vikunja_api/src/account/account_security_port.dart';
import 'package:vikunja_api/src/dto/account_security_codec.dart';
import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/write/write_transport.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

const _maxPages = 20;
const _totpNotSetUp = 1016;
const _sessionMissing = 16001;
const _totp = '/user/settings/totp';
const _sessions = '/user/sessions';
const _apiTokens = '/tokens';
const _caldavTokens = '/user/settings/token/caldav';

final class AccountSecurityApi implements AccountSecurityPort {
  new({required Dio dio, required ServerConnection connection})
    : _transport = WriteTransport(dio, connection),
      _perPage = connection.info.maxItemsPerPage;

  final WriteTransport _transport;
  final int _perPage;

  @override
  Future<TotpStatus> totpStatus() async {
    try {
      return _transport.decode<TotpStatus>(
        await _transport.send('GET', _totp),
        parseTotpStatus,
      );
    } on DomainError catch (failure) {
      if (failure.code == _totpNotSetUp) return TotpStatus.notSetUp;
      rethrow;
    }
  }

  @override
  Future<List<UserSession>> sessions() =>
      _allPages(_sessions, parseUserSession, idOf: (session) => session.id);

  @override
  Future<void> revokeSession(String id) async {
    try {
      await _transport.send('DELETE', '$_sessions/${Uri.encodeComponent(id)}');
    } on NotFound catch (failure) {
      if (failure.code != _sessionMissing) rethrow;
    }
  }

  @override
  Future<List<ApiToken>> apiTokens() =>
      _allPages(_apiTokens, parseApiToken, idOf: (token) => token.id);

  @override
  Future<ApiPermissionGroups> apiPermissions() async =>
      _transport.decode<ApiPermissionGroups>(
        await _transport.send('GET', '/routes'),
        parseApiPermissionGroups,
      );

  @override
  Future<CreatedApiToken> createApiToken(NewApiToken token) async {
    if (token.title.trim().isEmpty) {
      throw ArgumentError.value('', 'token.title', 'blank');
    }
    if (!token.expiresAt.isAfter(DateTime.now())) {
      throw ArgumentError.value(
        token.expiresAt,
        'token.expiresAt',
        'not in the future',
      );
    }
    return _transport.decode<CreatedApiToken>(
      await _transport.send(
        _transport.createMethod,
        _apiTokens,
        body: encodeNewApiToken(token),
      ),
      parseCreatedApiToken,
    );
  }

  @override
  Future<void> deleteApiToken(int id) async {
    await _transport.send('DELETE', '$_apiTokens/$id');
  }

  @override
  Future<List<CaldavToken>> caldavTokens() =>
      _allPages(_caldavTokens, parseCaldavToken, idOf: (token) => token.id);

  @override
  Future<CreatedCaldavToken> createCaldavToken() async =>
      _transport.decode<CreatedCaldavToken>(
        await _transport.send(_transport.createMethod, _caldavTokens),
        parseCreatedCaldavToken,
      );

  @override
  Future<void> deleteCaldavToken(int id) async {
    await _transport.send('DELETE', '$_caldavTokens/$id');
  }

  @override
  Future<UserDataExport?> dataExport() async =>
      _transport.decode<UserDataExport?>(
        await _transport.send('GET', '/user/export'),
        (json) => parseUserDataExport(_nullText(json) ? null : json),
      );

  /// v2 pages come in an envelope, v1 as an array with pagination headers;
  /// the v1 CalDAV list has neither page parameters nor headers. Ids seen on
  /// an earlier page are skipped: a refresh between two pages reorders the
  /// sessions.
  Future<List<T>> _allPages<T>(
    String path,
    T Function(Object?) parse, {
    required Object Function(T item) idOf,
  }) async {
    final byId = <Object, T>{};
    for (var page = 1; page <= _maxPages; page++) {
      final response = await _transport.send(
        'GET',
        path,
        query: {'page': '$page', 'per_page': '$_perPage'},
      );
      final (:items, :totalPages) = _transport.decode(
        response,
        (json) => _pageOf(json, response.headers, page, parse),
      );
      for (final item in items) {
        byId.putIfAbsent(idOf(item), () => item);
      }
      if (items.isEmpty || page >= totalPages) break;
    }
    return List.unmodifiable(byId.values);
  }

  static ({List<T> items, int totalPages}) _pageOf<T>(
    Object? json,
    Headers headers,
    int page,
    T Function(Object?) parse,
  ) => switch (json) {
    {'items': final List<Object?>? items, 'total_pages': final int pages} => (
      items: [...?items?.map(parse)],
      totalPages: pages,
    ),
    final List<Object?> items => (
      items: [...items.map(parse)],
      totalPages:
          int.tryParse(headers.value('x-pagination-total-pages') ?? '') ?? page,
    ),
    _ => throw const MalformedJson('not a page'),
  };

  static bool _nullText(Object? json) =>
      json is String && json.trim() == 'null';
}
