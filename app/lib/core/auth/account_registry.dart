import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

final _log = Logger('AccountRegistry');

/// An account with the server connection it was signed in through, so the
/// app can start offline.
@immutable
final class RegisteredAccount {
  const new({required this.account, required this.connection});

  final Account account;
  final ServerConnection connection;

  String get id => account.id;

  RegisteredAccount withAccount(Account account) =>
      RegisteredAccount(account: account, connection: connection);

  @override
  String toString() => 'RegisteredAccount($account)';
}

@immutable
final class AccountRegistryState {
  const new({this.accounts = const [], this.activeAccountId});

  final List<RegisteredAccount> accounts;
  final String? activeAccountId;

  RegisteredAccount? get activeAccount => find(activeAccountId);

  RegisteredAccount? find(String? accountId) {
    if (accountId == null) return null;
    for (final entry in accounts) {
      if (entry.id == accountId) return entry;
    }
    return null;
  }
}

/// Accounts and the active account id, without secrets. Storage is the
/// source of truth (other isolates may write it), so every operation reads
/// it again; writes within this isolate run one at a time.
///
/// Entries this version cannot read are left out of the state but written
/// back unchanged, so a write never erases an account (whose tokens are
/// still stored) just because a field changed shape.
final class AccountRegistry {
  new(this._store);

  static const storageKey = 'auth.account_registry';

  /// Where a registry that could not be read at all is copied before the
  /// first write replaces it.
  static const unreadableStorageKey = 'auth.account_registry.unreadable';
  static const _schemaVersion = 1;

  final PreferencesStore _store;
  final _changes = StreamController<AccountRegistryState>.broadcast();
  Future<void> _queue = Future.value();

  /// Emits after every write made through this instance.
  Stream<AccountRegistryState> get changes => _changes.stream;

  Future<AccountRegistryState> load() =>
      _serialized(() async => (await _read()).state);

  Future<RegisteredAccount?> find(String accountId) async =>
      (await load()).find(accountId);

  Future<AccountRegistryState> upsert(
    RegisteredAccount entry, {
    bool activate = false,
  }) => _update((state) {
    final accounts = [
      for (final existing in state.accounts)
        if (existing.id == entry.id) entry else existing,
      if (state.find(entry.id) == null) entry,
    ];
    return AccountRegistryState(
      accounts: accounts,
      activeAccountId: activate || state.activeAccountId == null
          ? entry.id
          : state.activeAccountId,
    );
  });

  /// Removing the active account activates the first remaining one.
  Future<AccountRegistryState> remove(String accountId) => _update((state) {
    final accounts = [
      for (final entry in state.accounts)
        if (entry.id != accountId) entry,
    ];
    final active = state.activeAccountId == accountId
        ? accounts.firstOrNull?.id
        : state.activeAccountId;
    return AccountRegistryState(accounts: accounts, activeAccountId: active);
  });

  Future<AccountRegistryState> setActive(String accountId) => _update(
    (state) => state.find(accountId) == null
        ? state
        : AccountRegistryState(
            accounts: state.accounts,
            activeAccountId: accountId,
          ),
  );

  Future<AccountRegistryState> markNeedsReauth(String accountId) => _update(
    (state) => AccountRegistryState(
      accounts: [
        for (final entry in state.accounts)
          if (entry.id == accountId)
            entry.withAccount(entry.account.copyWith(needsReauth: true))
          else
            entry,
      ],
      activeAccountId: state.activeAccountId,
    ),
  );

  Future<void> dispose() => _changes.close();

  Future<AccountRegistryState> _update(
    AccountRegistryState Function(AccountRegistryState state) change,
  ) => _serialized(() async {
    final stored = await _read();
    final next = change(stored.state);
    if (stored.unreadableRegistry case final raw?) {
      await _store.setString(unreadableStorageKey, raw);
    }
    // A readable entry with the same id (a new sign-in to that account)
    // replaces the unreadable one.
    final readableIds = {
      for (final entry in [...stored.state.accounts, ...next.accounts])
        entry.id,
    };
    final json = encodeRegistry(next);
    json['accounts'] = [
      ...json['accounts']! as List<Object?>,
      for (final raw in stored.unreadableEntries)
        if (!readableIds.contains(raw['id'])) raw,
    ];
    await _store.setString(storageKey, jsonEncode(json));
    if (!_changes.isClosed) _changes.add(next);
    return next;
  });

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<_StoredRegistry> _read() async {
    final raw = await _store.getString(storageKey);
    if (raw == null || raw.isEmpty) return const _StoredRegistry();
    try {
      final decoded = _decodeRegistry(jsonDecode(raw));
      return _StoredRegistry(
        state: decoded.state,
        unreadableEntries: decoded.unreadableEntries,
      );
    } on FormatException catch (error) {
      _log.severe(
        'Account registry is unreadable, starting empty: ${error.runtimeType}',
      );
      return _StoredRegistry(unreadableRegistry: raw);
    }
  }
}

final class _StoredRegistry {
  const new({
    this.state = const AccountRegistryState(),
    this.unreadableEntries = const [],
    this.unreadableRegistry,
  });

  final AccountRegistryState state;
  final List<Map<String, Object?>> unreadableEntries;
  final String? unreadableRegistry;
}

@visibleForTesting
Map<String, Object?> encodeRegistry(AccountRegistryState state) => {
  'version': AccountRegistry._schemaVersion,
  'active_account_id': state.activeAccountId,
  'accounts': [for (final entry in state.accounts) _encodeAccount(entry)],
};

/// Entries that cannot be read are left out (and logged) instead of failing
/// the whole registry.
@visibleForTesting
AccountRegistryState decodeRegistry(Object? json) =>
    _decodeRegistry(json).state;

({AccountRegistryState state, List<Map<String, Object?>> unreadableEntries})
_decodeRegistry(Object? json) {
  if (json is! Map<String, Object?>) {
    throw const FormatException('Account registry is not a JSON object');
  }
  final entries = switch (json['accounts']) {
    null => const <Object?>[],
    final List<Object?> list => list,
    _ => throw const FormatException('Stored accounts are not a list'),
  };
  final accounts = <RegisteredAccount>[];
  final unreadable = <Map<String, Object?>>[];
  for (final entry in entries) {
    try {
      accounts.add(_decodeAccount(entry));
    } on Object catch (error) {
      _log.warning('Skipping unreadable account entry: ${error.runtimeType}');
      if (entry is Map<String, Object?>) unreadable.add(entry);
    }
  }
  final active = json['active_account_id'];
  return (
    state: AccountRegistryState(
      accounts: List.unmodifiable(accounts),
      activeAccountId: accounts.any((entry) => entry.id == active)
          ? active! as String
          : accounts.firstOrNull?.id,
    ),
    unreadableEntries: unreadable,
  );
}

Map<String, Object?> _encodeAccount(RegisteredAccount entry) {
  final account = entry.account;
  final connection = entry.connection;
  return {
    'id': account.id,
    'server_root': account.serverRoot.toString(),
    'user_id': account.userId,
    'username': account.username,
    'display_name': account.displayName,
    'added_at': account.addedAt.toUtc().toIso8601String(),
    'needs_reauth': account.needsReauth,
    'connection': {
      'root_uri': connection.rootUri.toString(),
      'api_versions': [
        for (final version in ApiVersion.values)
          if (connection.apiVersions.contains(version)) version.name,
      ],
      'info': serverInfoToJson(connection.info),
    },
  };
}

RegisteredAccount _decodeAccount(Object? json) {
  final map = json! as Map<String, Object?>;
  final connection = map['connection']! as Map<String, Object?>;
  final apiVersions = {
    for (final name in connection['api_versions']! as List<Object?>)
      ?ApiVersion.values.asNameMap()[name],
  };
  if (apiVersions.isEmpty) {
    throw const FormatException('Stored connection has no API version');
  }
  final info = parseServerInfo(connection['info']! as Map<String, Object?>);
  return RegisteredAccount(
    account: Account(
      id: map['id']! as String,
      serverRoot: Uri.parse(map['server_root']! as String),
      userId: map['user_id']! as int,
      username: map['username']! as String,
      displayName: map['display_name']! as String,
      addedAt: DateTime.parse(map['added_at']! as String),
      needsReauth: map['needs_reauth'] == true,
    ),
    connection: ServerConnection(
      rootUri: Uri.parse(connection['root_uri']! as String),
      apiVersions: Set.unmodifiable(apiVersions),
      info: info,
      capabilities: ServerCapabilities.derive(
        info: info,
        apiVersions: apiVersions,
      ),
    ),
  );
}
