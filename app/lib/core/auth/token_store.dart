import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/storage/secure_store.dart';

@immutable
final class StoredTokens {
  const new({required this.accessToken, required this.refreshToken});

  /// Empty when only the refresh token survived.
  final String accessToken;
  final String refreshToken;

  @override
  String toString() => 'StoredTokens([redacted])';
}

final class TokenStore {
  new(this._store);

  final SecureStore _store;

  static String refreshTokenKey(String accountId) =>
      'account.$accountId.refresh_token';

  static String accessTokenKey(String accountId) =>
      'account.$accountId.access_token';

  Future<StoredTokens?> read(String accountId) async {
    final refreshToken = await _store.read(refreshTokenKey(accountId));
    if (refreshToken == null || refreshToken.isEmpty) return null;
    final accessToken = await _store.read(accessTokenKey(accountId));
    return StoredTokens(
      accessToken: accessToken ?? '',
      refreshToken: refreshToken,
    );
  }

  // The refresh token goes first: Vikunja has already invalidated the old one,
  // so it must survive a crash between the two writes. A stale access token
  // only costs one more refresh.
  Future<void> write(String accountId, TokenSet tokens) async {
    await _store.write(refreshTokenKey(accountId), tokens.refreshToken);
    await _store.write(accessTokenKey(accountId), tokens.accessToken);
  }

  Future<void> delete(String accountId) async {
    await _store.delete(accessTokenKey(accountId));
    await _store.delete(refreshTokenKey(accountId));
  }
}
