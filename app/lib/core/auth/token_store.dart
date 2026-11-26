import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/storage/process_lock.dart';
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

/// Secure storage refused a read (a Keystore or Keychain failure): the
/// tokens may still be there, unlike a read that finds none.
final class SecureStorageUnreadable implements Exception {
  const new(this.errorType);

  /// Only the type: platform errors can echo stored values.
  final Type errorType;

  @override
  String toString() => 'SecureStorageUnreadable($errorType)';
}

final class TokenStore {
  new(this._store);

  final SecureStore _store;

  static String refreshTokenKey(String accountId) =>
      'account.$accountId.refresh_token';

  static String accessTokenKey(String accountId) =>
      'account.$accountId.access_token';

  /// Serializes credential changes for [accountId] across isolates. The
  /// callback must only touch local storage, never wait on the server.
  Future<T> mutate<T>(
    String accountId,
    Future<T> Function(AccountTokenMutation) action,
  ) => ProcessLock(
    'vikunja.account-tokens.$accountId',
    requireLock: true,
  ).run(() => action(AccountTokenMutation._(this, accountId)));

  /// Throws [SecureStorageUnreadable] when storage refuses to read.
  Future<StoredTokens?> read(String accountId) async {
    try {
      final refreshToken = await _store.read(refreshTokenKey(accountId));
      if (refreshToken == null || refreshToken.isEmpty) return null;
      final accessToken = await _store.read(accessTokenKey(accountId));
      return StoredTokens(
        accessToken: accessToken ?? '',
        refreshToken: refreshToken,
      );
    } on Object catch (error) {
      throw SecureStorageUnreadable(error.runtimeType);
    }
  }

  Future<void> write(
    String accountId,
    TokenSet tokens, {
    bool recoverLostKey = false,
  }) => mutate(
    accountId,
    (store) => store.write(tokens, recoverLostKey: recoverLostKey),
  );

  Future<void> delete(String accountId) =>
      mutate(accountId, (store) => store.delete());
}

/// Credential access inside [TokenStore.mutate]'s lock.
final class AccountTokenMutation {
  const new _(this._tokens, this._accountId);

  final TokenStore _tokens;
  final String _accountId;

  Future<StoredTokens?> read() => _tokens.read(_accountId);

  /// The refresh token goes first: Vikunja has already invalidated the old
  /// one, so its replacement must survive a crash between writes.
  /// Only sign-in may ask to [recoverLostKey] by resetting secure storage.
  Future<void> write(TokenSet tokens, {bool recoverLostKey = false}) async {
    final store = _tokens._store;
    await store.write(
      TokenStore.refreshTokenKey(_accountId),
      tokens.refreshToken,
      recoverLostKey: recoverLostKey,
    );
    await store.write(
      TokenStore.accessTokenKey(_accountId),
      tokens.accessToken,
    );
    await store.flush();
  }

  Future<void> delete() async {
    final store = _tokens._store;
    await store.delete(TokenStore.accessTokenKey(_accountId));
    await store.delete(TokenStore.refreshTokenKey(_accountId));
  }
}
