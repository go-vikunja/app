import 'dart:math';

import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/platform/sensitive_clipboard.dart';
import 'package:vikunja_mobile/core/repositories/account_security_repository.dart';

const fakeCurrentSessionId = '6f1c2a3b-0000-4000-8000-000000000001';
const fakeWebSessionId = '6f1c2a3b-0000-4000-8000-000000000002';
const fakeScriptSessionId = '6f1c2a3b-0000-4000-8000-000000000003';

/// This app on an Android phone (the current session), Firefox on Linux and
/// a script, most recently active first as the server orders them.
List<UserSession> fakeSessions(DateTime now) => [
  UserSession(
    id: fakeCurrentSessionId,
    deviceInfo: 'Rurana/0.31.0+31 (android 15)',
    ipAddress: '192.0.2.10',
    created: now.subtract(const Duration(days: 2)),
    lastActive: now.subtract(const Duration(minutes: 3)),
  ),
  UserSession(
    id: fakeWebSessionId,
    deviceInfo:
        'Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 '
        'Firefox/140.0',
    ipAddress: '198.51.100.23',
    created: now.subtract(const Duration(days: 5)),
    lastActive: now.subtract(const Duration(hours: 4)),
  ),
  UserSession(
    id: fakeScriptSessionId,
    deviceInfo: 'Dart/3.9 (dart:io)',
    ipAddress: '203.0.113.5',
    created: now.subtract(const Duration(days: 9)),
    lastActive: now.subtract(const Duration(days: 8)),
  ),
];

/// A few groups of `GET /routes`, in the server's alphabetical order with
/// `other` among them.
final fakeApiPermissionGroups = ApiPermissionGroups(const {
  'caldav': ['access'],
  'labels': ['create', 'delete', 'read_all', 'read_one', 'update'],
  'other': ['routes', 'user'],
  'projects': ['create', 'delete', 'read_all', 'read_one', 'update'],
  'tasks': ['create', 'delete', 'read_all', 'read_one', 'update'],
});

ApiToken fakeApiToken({
  required DateTime expiresAt,
  int id = 1,
  String title = 'Home Assistant',
  Map<String, List<String>> permissions = const {
    'tasks': ['read_all', 'update'],
  },
  DateTime? created,
}) => ApiToken(
  id: id,
  title: title,
  permissions: permissions,
  expiresAt: expiresAt,
  created: created ?? expiresAt.subtract(const Duration(days: 30)),
);

/// Shaped like real values (`tk_` and 40 hex digits; 64 letters and digits)
/// but made up, so a test can look for them where they must not be.
String fakeApiTokenSecret(int id) =>
    'tk_${id.toRadixString(16).padLeft(40, '0')}';

String fakeCaldavTokenSecret(int id) => 'Cd${'$id'.padLeft(62, '0')}';

int _nextId(Iterable<int> ids) => ids.fold(0, max) + 1;

/// The account's security settings in memory, as the real repository would
/// read them from the server: [totp], [sessionList] with [currentSession] as
/// this app's, [apiTokenList], [permissions], [caldavTokenList] and [export].
/// Changes apply to these lists; a new token gets the next id, [now] as its
/// creation and a made-up value ([fakeApiTokenSecret],
/// [fakeCaldavTokenSecret]).
///
/// Every call is recorded in [calls] first: `totpStatus`, `sessions`,
/// `currentSessionId`, `revokeSession <id>`, `revokeOtherSessions`,
/// `apiTokens`, `apiPermissions`, `createApiToken`, `deleteApiToken <id>`,
/// `caldavTokens`, `createCaldavToken`, `deleteCaldavToken <id>`,
/// `dataExport`; [beforeCall] can hold one, and [failure] or the entry of
/// [failures] for the method name is thrown instead while set, with
/// nothing changed. Ended sessions are added to [revoked], the requests of
/// [createApiToken] to [createdApiTokens]; an entry of [revokeFailures]
/// fails that session's end, also inside [revokeOtherSessions]. The real
/// repository's checks apply: the current session cannot be revoked here,
/// [revokeOtherSessions] needs [currentSession], and a token without a
/// title, without permissions or not expiring after [now] is an
/// `ArgumentError`; an unknown API token is `Forbidden`, while unknown
/// sessions and CalDAV tokens are deleted silently.
final class FakeAccountSecurityRepository implements AccountSecurityRepository {
  new({
    this.totp = TotpStatus.notSetUp,
    List<UserSession>? sessions,
    this.currentSession = fakeCurrentSessionId,
    List<ApiToken>? apiTokens,
    ApiPermissionGroups? permissions,
    List<CaldavToken>? caldavTokens,
    this.export,
    this.now = DateTime.now,
  }) : sessionList = sessions ?? fakeSessions(now()),
       apiTokenList = apiTokens ?? [],
       permissions = permissions ?? fakeApiPermissionGroups,
       caldavTokenList = caldavTokens ?? [];

  TotpStatus totp;
  List<UserSession> sessionList;
  String? currentSession;
  List<ApiToken> apiTokenList;
  ApiPermissionGroups permissions;
  List<CaldavToken> caldavTokenList;
  UserDataExport? export;
  DateTime Function() now;

  final List<String> calls = [];
  final List<String> revoked = [];
  final List<NewApiToken> createdApiTokens = [];
  Exception? failure;
  final Map<String, Exception> failures = {};
  final Map<String, VikunjaFailure> revokeFailures = {};
  Future<void> Function(String call)? beforeCall;

  @override
  Future<TotpStatus> totpStatus() async {
    await _call('totpStatus', '');
    return totp;
  }

  @override
  Future<List<UserSession>> sessions() async {
    await _call('sessions', '');
    return List.unmodifiable(sessionList);
  }

  @override
  Future<String?> currentSessionId() async {
    await _call('currentSessionId', '');
    return currentSession;
  }

  @override
  Future<void> revokeSession(String id) async {
    await _call('revokeSession', id);
    if (id == currentSession) throw ArgumentError.value(id, 'id');
    _revoke(id);
  }

  @override
  Future<int> revokeOtherSessions() async {
    await _call('revokeOtherSessions', '');
    final current = currentSession;
    if (current == null) {
      throw const SessionEnded(SessionEndReason.invalidRefreshToken);
    }
    final others = [
      for (final session in sessionList)
        if (session.id != current) session.id,
    ];
    for (final (index, id) in others.indexed) {
      try {
        _revoke(id);
      } on VikunjaFailure catch (failure) {
        throw OtherSessionsNotAllEnded(
          ended: index,
          notEnded: others.length - index,
          failure: failure,
        );
      }
    }
    return others.length;
  }

  void _revoke(String id) {
    if (revokeFailures[id] case final failure?) throw failure;
    sessionList = [
      for (final session in sessionList)
        if (session.id != id) session,
    ];
    revoked.add(id);
  }

  @override
  Future<List<ApiToken>> apiTokens() async {
    await _call('apiTokens', '');
    return List.unmodifiable(apiTokenList);
  }

  @override
  Future<ApiPermissionGroups> apiPermissions() async {
    await _call('apiPermissions', '');
    return permissions;
  }

  @override
  Future<CreatedApiToken> createApiToken(NewApiToken token) async {
    createdApiTokens.add(token);
    await _call('createApiToken', '');
    if (token.title.trim().isEmpty ||
        token.permissions.values.every((names) => names.isEmpty) ||
        !token.expiresAt.isAfter(now())) {
      throw ArgumentError.value(token, 'token');
    }
    final created = ApiToken(
      id: _nextId(apiTokenList.map((token) => token.id)),
      title: token.title,
      permissions: token.permissions,
      expiresAt: token.expiresAt,
      created: now(),
    );
    apiTokenList = [...apiTokenList, created];
    return CreatedApiToken(
      token: created,
      secret: fakeApiTokenSecret(created.id),
    );
  }

  @override
  Future<void> deleteApiToken(int id) async {
    await _call('deleteApiToken', '$id');
    if (!apiTokenList.any((token) => token.id == id)) throw const Forbidden();
    apiTokenList = [
      for (final token in apiTokenList)
        if (token.id != id) token,
    ];
  }

  @override
  Future<List<CaldavToken>> caldavTokens() async {
    await _call('caldavTokens', '');
    return List.unmodifiable(caldavTokenList);
  }

  @override
  Future<CreatedCaldavToken> createCaldavToken() async {
    await _call('createCaldavToken', '');
    final created = CaldavToken(
      id: _nextId(caldavTokenList.map((token) => token.id)),
      created: now(),
    );
    caldavTokenList = [...caldavTokenList, created];
    return CreatedCaldavToken(
      token: created,
      secret: fakeCaldavTokenSecret(created.id),
    );
  }

  @override
  Future<void> deleteCaldavToken(int id) async {
    await _call('deleteCaldavToken', '$id');
    caldavTokenList = [
      for (final token in caldavTokenList)
        if (token.id != id) token,
    ];
  }

  @override
  Future<UserDataExport?> dataExport() async {
    await _call('dataExport', '');
    return export;
  }

  Future<void> _call(String method, String detail) async {
    calls.add(detail.isEmpty ? method : '$method $detail');
    await beforeCall?.call(calls.last);
    if (failures[method] ?? failure case final failure?) throw failure;
  }
}

/// [AccountSecurityPort] in memory, answering as the real port does: a
/// session that is gone already counts as ended, an unknown API token is
/// `Forbidden`, an unknown CalDAV token a silent success, and a token with
/// a blank title or not expiring after [now] an `ArgumentError` before any
/// request. Every request is logged in [requests] first (`sessions`,
/// `revokeSession <id>`, …); [failure], the entry of [failures] for the
/// method name or, for a revoke, the entry of [revokeFailures] for the id is
/// thrown instead.
final class FakeAccountSecurityPort implements AccountSecurityPort {
  new({
    this.totp = TotpStatus.notSetUp,
    List<UserSession>? sessions,
    List<ApiToken>? apiTokens,
    ApiPermissionGroups? permissions,
    List<CaldavToken>? caldavTokens,
    this.export,
    this.now = DateTime.now,
  }) : sessionList = sessions ?? fakeSessions(now()),
       apiTokenList = apiTokens ?? [],
       permissions = permissions ?? fakeApiPermissionGroups,
       caldavTokenList = caldavTokens ?? [];

  TotpStatus totp;
  List<UserSession> sessionList;
  List<ApiToken> apiTokenList;
  ApiPermissionGroups permissions;
  List<CaldavToken> caldavTokenList;
  UserDataExport? export;
  DateTime Function() now;

  final List<String> requests = [];
  Exception? failure;
  final Map<String, Exception> failures = {};
  final Map<String, Exception> revokeFailures = {};
  Future<void> Function(String request)? beforeRequest;

  @override
  Future<TotpStatus> totpStatus() async {
    await _request('totpStatus', '');
    return totp;
  }

  @override
  Future<List<UserSession>> sessions() async {
    await _request('sessions', '');
    return List.unmodifiable(sessionList);
  }

  @override
  Future<void> revokeSession(String id) async {
    await _request('revokeSession', id);
    if (revokeFailures[id] case final failure?) throw failure;
    sessionList = [
      for (final session in sessionList)
        if (session.id != id) session,
    ];
  }

  @override
  Future<List<ApiToken>> apiTokens() async {
    await _request('apiTokens', '');
    return List.unmodifiable(apiTokenList);
  }

  @override
  Future<ApiPermissionGroups> apiPermissions() async {
    await _request('apiPermissions', '');
    return permissions;
  }

  @override
  Future<CreatedApiToken> createApiToken(NewApiToken token) async {
    if (token.title.trim().isEmpty || !token.expiresAt.isAfter(now())) {
      throw ArgumentError.value(token, 'token');
    }
    await _request('createApiToken', '');
    final id = _nextId(apiTokenList.map((token) => token.id));
    final created = ApiToken(
      id: id,
      title: token.title,
      permissions: token.permissions,
      expiresAt: token.expiresAt,
      created: now(),
    );
    apiTokenList = [...apiTokenList, created];
    return CreatedApiToken(token: created, secret: fakeApiTokenSecret(id));
  }

  @override
  Future<void> deleteApiToken(int id) async {
    await _request('deleteApiToken', '$id');
    if (!apiTokenList.any((token) => token.id == id)) throw const Forbidden();
    apiTokenList = [
      for (final token in apiTokenList)
        if (token.id != id) token,
    ];
  }

  @override
  Future<List<CaldavToken>> caldavTokens() async {
    await _request('caldavTokens', '');
    return List.unmodifiable(caldavTokenList);
  }

  @override
  Future<CreatedCaldavToken> createCaldavToken() async {
    await _request('createCaldavToken', '');
    final id = _nextId(caldavTokenList.map((token) => token.id));
    final created = CaldavToken(id: id, created: now());
    caldavTokenList = [...caldavTokenList, created];
    return CreatedCaldavToken(
      token: created,
      secret: fakeCaldavTokenSecret(id),
    );
  }

  @override
  Future<void> deleteCaldavToken(int id) async {
    await _request('deleteCaldavToken', '$id');
    caldavTokenList = [
      for (final token in caldavTokenList)
        if (token.id != id) token,
    ];
  }

  @override
  Future<UserDataExport?> dataExport() async {
    await _request('dataExport', '');
    return export;
  }

  Future<void> _request(String method, String detail) async {
    requests.add(detail.isEmpty ? method : '$method $detail');
    await beforeRequest?.call(requests.last);
    if (failures[method] ?? failure case final failure?) throw failure;
  }
}

/// Keeps what was copied in [copied]; [failure] is thrown instead while set.
final class FakeSensitiveClipboard implements SensitiveClipboard {
  final List<String> copied = [];
  Exception? failure;

  @override
  Future<void> copy(String text) async {
    if (failure case final failure?) throw failure;
    copied.add(text);
  }
}
