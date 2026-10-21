import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/account_security_repository.dart';

final class OnlineAccountSecurityRepository
    implements AccountSecurityRepository {
  new({
    required this._port,
    required this._currentSessionId,
    this._now = DateTime.now,
  });

  final AccountSecurityPort _port;
  final Future<String?> Function() _currentSessionId;
  final DateTime Function() _now;

  @override
  Future<TotpStatus> totpStatus() => _port.totpStatus();

  @override
  Future<List<UserSession>> sessions() => _port.sessions();

  @override
  Future<String?> currentSessionId() => _currentSessionId();

  @override
  Future<void> revokeSession(String id) async {
    if (id == await _currentSessionId()) {
      throw ArgumentError.value(id, 'id', 'is the current session');
    }
    await _port.revokeSession(id);
  }

  @override
  Future<int> revokeOtherSessions() async {
    final current = await _currentSessionId();
    // Without it, the app's own session would be ended with the others.
    if (current == null) {
      throw const SessionEnded(SessionEndReason.invalidRefreshToken);
    }
    final others = [
      for (final session in await _port.sessions())
        if (session.id != current) session.id,
    ];
    for (final (index, id) in others.indexed) {
      try {
        await _port.revokeSession(id);
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

  @override
  Future<List<ApiToken>> apiTokens() => _port.apiTokens();

  @override
  Future<ApiPermissionGroups> apiPermissions() => _port.apiPermissions();

  @override
  Future<CreatedApiToken> createApiToken(NewApiToken token) async {
    if (token.title.trim().isEmpty) {
      throw ArgumentError.value(token, 'token', 'has no title');
    }
    if (token.permissions.values.every((names) => names.isEmpty)) {
      throw ArgumentError.value(token, 'token', 'has no permission');
    }
    if (!token.expiresAt.isAfter(_now())) {
      throw ArgumentError.value(token, 'token', 'has expired already');
    }
    return await _port.createApiToken(token);
  }

  @override
  Future<void> deleteApiToken(int id) => _port.deleteApiToken(id);

  @override
  Future<List<CaldavToken>> caldavTokens() => _port.caldavTokens();

  @override
  Future<CreatedCaldavToken> createCaldavToken() => _port.createCaldavToken();

  @override
  Future<void> deleteCaldavToken(int id) => _port.deleteCaldavToken(id);

  @override
  Future<UserDataExport?> dataExport() => _port.dataExport();
}
