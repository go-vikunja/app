import 'dart:convert';

import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

/// The plain http account that [entry], a user account over https, stands
/// in for: the same user (id and name) on the same host and path, where the
/// Connection page of an http address looks for https. With both signed
/// in, every reminder comes twice.
RegisteredAccount? httpTwinOf(
  Iterable<RegisteredAccount> accounts,
  RegisteredAccount entry,
) {
  if (entry.connection.rootUri.scheme != 'https') return null;
  for (final other in accounts) {
    if (other.connection.rootUri.scheme == 'http' && _sameUser(entry, other)) {
      return other;
    }
  }
  return null;
}

/// Whether a user account over https stands in for [entry], a plain http
/// one (see [httpTwinOf]).
bool hasHttpsTwin(
  Iterable<RegisteredAccount> accounts,
  RegisteredAccount entry,
) =>
    entry.connection.rootUri.scheme == 'http' &&
    accounts.any(
      (other) =>
          other.connection.rootUri.scheme == 'https' && _sameUser(other, entry),
    );

final _trailingSlashes = RegExp(r'/+$');

bool _sameUser(RegisteredAccount a, RegisteredAccount b) {
  if (a.account.isLinkShare || b.account.isLinkShare) return false;
  final rootA = a.connection.rootUri;
  final rootB = b.connection.rootUri;
  return a.account.userId == b.account.userId &&
      a.account.username == b.account.username &&
      rootA.host == rootB.host &&
      rootA.path.replaceFirst(_trailingSlashes, '') ==
          rootB.path.replaceFirst(_trailingSlashes, '');
}

/// The http twins the user chose to keep when asked to remove them, with
/// how many changes each had unsent then; account ids only. What cannot be
/// read counts as not kept, so the question comes again.
final class KeptHttpTwins {
  const new(this._preferences);

  static const storageKey = 'accounts.kept_http_twins';

  final PreferencesStore _preferences;

  Future<int?> unsentWhenKept(String accountId) async =>
      (await _read())[accountId];

  /// Forgets accounts no longer among [accountIds].
  Future<void> keep(
    String accountId, {
    required int unsent,
    required Set<String> accountIds,
  }) async {
    final kept = {
      for (final MapEntry(:key, :value) in (await _read()).entries)
        if (accountIds.contains(key)) key: value,
      accountId: unsent,
    };
    await _preferences.setString(storageKey, jsonEncode(kept));
  }

  Future<Map<String, int>> _read() async {
    final stored = await _preferences.getString(storageKey);
    if (stored == null) return {};
    final Object? decoded;
    try {
      decoded = jsonDecode(stored);
    } on FormatException {
      return {};
    }
    if (decoded is! Map<String, Object?>) return {};
    return {
      for (final MapEntry(:key, :value) in decoded.entries)
        if (value case final int unsent) key: unsent,
    };
  }
}
