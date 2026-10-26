import 'package:flutter/foundation.dart';
import 'package:vikunja_mobile/core/storage/secure_store.dart';

@immutable
final class StoredLinkShare {
  const new({required this.hash, this.token});

  /// The link's long-lived secret, which authenticates again once the
  /// token has expired.
  final String hash;

  /// Null once only the hash survived.
  final String? token;

  @override
  String toString() => 'StoredLinkShare([redacted])';
}

/// A guest's secrets in secure storage, apart from the OAuth tokens of
/// users. The share's password is never stored: a share that has one asks
/// for it again when the hash alone cannot authenticate.
final class LinkShareStore {
  new(this._store);

  final SecureStore _store;

  static String hashKey(String accountId) => 'account.$accountId.share_hash';

  static String tokenKey(String accountId) => 'account.$accountId.share_token';

  Future<StoredLinkShare?> read(String accountId) async {
    final hash = await _store.read(hashKey(accountId));
    if (hash == null || hash.isEmpty) return null;
    final token = await _store.read(tokenKey(accountId));
    return StoredLinkShare(
      hash: hash,
      token: token == null || token.isEmpty ? null : token,
    );
  }

  // The hash goes first: without it a stored token could not be renewed
  // once it expires, while a missing token only costs one authentication.
  Future<void> write(
    String accountId, {
    required String hash,
    required String token,
  }) async {
    await _store.write(hashKey(accountId), hash);
    await _store.write(tokenKey(accountId), token);
  }

  Future<void> writeToken(String accountId, String token) =>
      _store.write(tokenKey(accountId), token);

  // The hash goes first: a token another isolate writes meanwhile is then
  // taken back by that writer (`LinkShareSession`), which checks the hash
  // again after its write.
  Future<void> delete(String accountId) async {
    await _store.delete(hashKey(accountId));
    await _store.delete(tokenKey(accountId));
  }
}
