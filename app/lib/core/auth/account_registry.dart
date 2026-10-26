import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

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
  const new({
    this.accounts = const [],
    this.activeAccountId,
    this.recentAccountIds = const [],
  });

  /// In the order they were added.
  final List<RegisteredAccount> accounts;
  final String? activeAccountId;

  /// The order in which the accounts were last active, most recent first.
  final List<String> recentAccountIds;

  RegisteredAccount? get activeAccount => find(activeAccountId);

  /// The active account first, then the others from the most recently
  /// active; accounts [recentAccountIds] misses follow in stored order.
  List<RegisteredAccount> get accountsByRecency => [
    for (final id in _recencyOrder) find(id)!,
  ];

  RegisteredAccount? find(String? accountId) {
    if (accountId == null) return null;
    for (final entry in accounts) {
      if (entry.id == accountId) return entry;
    }
    return null;
  }

  List<String> get _recencyOrder {
    final ids = {for (final entry in accounts) entry.id};
    return {
      if (activeAccount != null) activeAccountId!,
      for (final id in recentAccountIds)
        if (ids.contains(id)) id,
      ...ids,
    }.toList();
  }
}

/// A state whose recency names every account once, the active one first.
AccountRegistryState _ordered({
  required List<RegisteredAccount> accounts,
  required String? activeAccountId,
  required List<String> recentAccountIds,
}) => AccountRegistryState(
  accounts: List.unmodifiable(accounts),
  activeAccountId: activeAccountId,
  recentAccountIds: List.unmodifiable(
    AccountRegistryState(
      accounts: accounts,
      activeAccountId: activeAccountId,
      recentAccountIds: recentAccountIds,
    )._recencyOrder,
  ),
);

/// Accounts and the active account id, without secrets. Storage is the
/// source of truth (other isolates may write it), so every operation reads
/// it again; writes within this isolate run one at a time.
///
/// Entries this version cannot read are left out of the state but written
/// back unchanged and in their place, so a write never erases an account
/// (whose tokens are still stored) just because a field changed shape.
final class AccountRegistry {
  new(this._store);

  static const storageKey = 'auth.account_registry';

  /// Where a registry that could not be read at all is copied before the
  /// first write replaces it.
  static const unreadableStorageKey = 'auth.account_registry.unreadable';
  static const _schemaVersion = 1;

  final PreferencesStore _store;
  final _changes = StreamController<AccountRegistryState>.broadcast();
  AccountRegistryState? _announced;
  Future<void> _queue = Future.value();

  /// Emits after every write made through this instance, and when
  /// [updateDisplayName] or [updateGuestTitle] finds a name another isolate
  /// stored that this one has not announced yet.
  Stream<AccountRegistryState> get changes => _changes.stream;

  Future<AccountRegistryState> load() =>
      _serialized(() async => (await _read()).state);

  Future<RegisteredAccount?> find(String accountId) async =>
      (await load()).find(accountId);

  Future<AccountRegistryState> upsert(
    RegisteredAccount entry, {
    bool activate = false,
  }) => _update(
    (state) => _ordered(
      accounts: [
        for (final existing in state.accounts)
          if (existing.id == entry.id) entry else existing,
        if (state.find(entry.id) == null) entry,
      ],
      activeAccountId: activate || state.activeAccountId == null
          ? entry.id
          : state.activeAccountId,
      recentAccountIds: state.recentAccountIds,
    ),
  );

  /// Removing the active account activates the most recently active one of
  /// the rest.
  Future<AccountRegistryState> remove(String accountId) => _update((state) {
    final rest = _ordered(
      accounts: [
        for (final entry in state.accounts)
          if (entry.id != accountId) entry,
      ],
      activeAccountId: state.activeAccountId == accountId
          ? null
          : state.activeAccountId,
      recentAccountIds: state.recentAccountIds,
    );
    if (rest.activeAccountId != null) return rest;
    return _ordered(
      accounts: rest.accounts,
      activeAccountId: rest.recentAccountIds.firstOrNull,
      recentAccountIds: rest.recentAccountIds,
    );
  });

  Future<AccountRegistryState> setActive(String accountId) => _update(
    (state) => state.find(accountId) == null
        ? state
        : _ordered(
            accounts: state.accounts,
            activeAccountId: accountId,
            recentAccountIds: state.recentAccountIds,
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
      recentAccountIds: state.recentAccountIds,
    ),
  );

  /// [name] as the server has it: a blank one shows the username, as at
  /// sign-in. An account that already shows it is not written. Never
  /// throws: the name is only shown, and the next sync tries again.
  Future<void> updateDisplayName(String accountId, String name) => _storeName(
    accountId,
    (state) => _withDisplayName(state, accountId, name),
  );

  /// A guest whose share has no name goes by its project's [title], which
  /// the owner may change; like [updateDisplayName] otherwise.
  Future<void> updateGuestTitle(String accountId, String title) => _storeName(
    accountId,
    (state) => _withGuestTitle(state, accountId, title),
  );

  Future<void> _storeName(
    String accountId,
    AccountRegistryState? Function(AccountRegistryState state) change,
  ) async {
    String? shownName(AccountRegistryState? state) =>
        state?.find(accountId)?.account.displayName;
    try {
      await _update(
        change,
        // A background run may have stored the name already; this isolate's
        // listeners still show the old one.
        announceUnchanged: (stored) =>
            shownName(stored) != shownName(_announced),
      );
    } on Object catch (error) {
      _log.warning(
        'Could not store the name of account $accountId: ${error.runtimeType}',
      );
    }
  }

  static AccountRegistryState? _withGuestTitle(
    AccountRegistryState state,
    String accountId,
    String title,
  ) {
    final account = state.find(accountId)?.account;
    final trimmed = title.trim();
    if (account == null ||
        !account.isLinkShare ||
        (account.shareName?.trim() ?? '') != '' ||
        trimmed.isEmpty ||
        account.displayName == trimmed) {
      return null;
    }
    return _withAccount(state, account.copyWith(displayName: trimmed));
  }

  static AccountRegistryState? _withDisplayName(
    AccountRegistryState state,
    String accountId,
    String name,
  ) {
    final entry = state.find(accountId);
    // The server names a guest "Link Share"; the app keeps its own name.
    if (entry == null || entry.account.isLinkShare) return null;
    final displayName = User(
      id: entry.account.userId,
      username: entry.account.username,
      name: name,
    ).displayName;
    if (entry.account.displayName == displayName) return null;
    return _withAccount(
      state,
      entry.account.copyWith(displayName: displayName),
    );
  }

  static AccountRegistryState _withAccount(
    AccountRegistryState state,
    Account account,
  ) => AccountRegistryState(
    accounts: [
      for (final existing in state.accounts)
        if (existing.id == account.id)
          existing.withAccount(account)
        else
          existing,
    ],
    activeAccountId: state.activeAccountId,
    recentAccountIds: state.recentAccountIds,
  );

  Future<void> dispose() => _changes.close();

  /// A change that returns null leaves storage as it is, and announces the
  /// stored state only when [announceUnchanged] says so.
  Future<AccountRegistryState> _update(
    AccountRegistryState? Function(AccountRegistryState state) change, {
    bool Function(AccountRegistryState stored)? announceUnchanged,
  }) => _serialized(() async {
    final stored = await _read();
    final next = change(stored.state);
    if (next == null) {
      if (announceUnchanged?.call(stored.state) ?? false) {
        _announce(stored.state);
      }
      return stored.state;
    }
    if (stored.unreadableRegistry case final raw?) {
      await _store.setString(unreadableStorageKey, raw);
    }
    // A readable entry with the same id (a new sign-in to that account)
    // replaces the unreadable one.
    final readableIds = {
      for (final entry in [...stored.state.accounts, ...next.accounts])
        entry.id,
    };
    final kept = [
      for (final (index, raw) in stored.unreadableEntries)
        if (!readableIds.contains(raw['id'])) (index, raw),
    ];
    final keptIds = {for (final (_, raw) in kept) raw['id']};
    final json = encodeRegistry(next);
    json['accounts'] = _insertKept(json['accounts']! as List<Object?>, kept);
    json['recent_account_ids'] = _insertKept(
      json['recent_account_ids']! as List<Object?>,
      [
        for (final (index, id) in stored.storedRecentIds.indexed)
          if (keptIds.contains(id)) (index, id),
      ],
    );
    await _store.setString(storageKey, jsonEncode(json));
    _announce(next);
    return next;
  });

  void _announce(AccountRegistryState state) {
    _announced = state;
    if (!_changes.isClosed) _changes.add(state);
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<_StoredRegistry> _read() async {
    final raw = await _store.getString(storageKey);
    if (raw == null || raw.isEmpty) return const _StoredRegistry();
    try {
      return _decodeRegistry(jsonDecode(raw));
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
    this.storedRecentIds = const [],
    this.unreadableRegistry,
  });

  final AccountRegistryState state;

  /// With their index in the stored list, where a write puts them back.
  final List<(int, Map<String, Object?>)> unreadableEntries;

  /// The stored recency, unreadable entries included.
  final List<String> storedRecentIds;
  final String? unreadableRegistry;
}

/// Puts entries this version cannot read back at their stored index, so
/// writes keep their place.
List<Object?> _insertKept(List<Object?> written, List<(int, Object?)> kept) {
  final result = [...written];
  for (final (index, value) in kept) {
    result.insert(math.min(index, result.length), value);
  }
  return result;
}

@visibleForTesting
Map<String, Object?> encodeRegistry(AccountRegistryState state) => {
  'version': AccountRegistry._schemaVersion,
  'active_account_id': state.activeAccountId,
  'recent_account_ids': state._recencyOrder,
  'accounts': [for (final entry in state.accounts) _encodeAccount(entry)],
};

/// Entries that cannot be read are left out (and logged) instead of failing
/// the whole registry.
@visibleForTesting
AccountRegistryState decodeRegistry(Object? json) =>
    _decodeRegistry(json).state;

_StoredRegistry _decodeRegistry(Object? json) {
  if (json is! Map<String, Object?>) {
    throw const FormatException('Account registry is not a JSON object');
  }
  final entries = switch (json['accounts']) {
    null => const <Object?>[],
    final List<Object?> list => list,
    _ => throw const FormatException('Stored accounts are not a list'),
  };
  final accounts = <RegisteredAccount>[];
  final unreadable = <(int, Map<String, Object?>)>[];
  for (final (index, entry) in entries.indexed) {
    try {
      accounts.add(_decodeAccount(entry));
    } on Object catch (error) {
      _log.warning('Skipping unreadable account entry: ${error.runtimeType}');
      if (entry is Map<String, Object?>) unreadable.add((index, entry));
    }
  }
  final storedActive = json['active_account_id'];
  // Registries written before the recency was stored: the stored order,
  // with the active account first.
  final storedRecent = switch (json['recent_account_ids']) {
    final List<Object?> ids => [
      for (final id in ids)
        if (id is String) id,
    ],
    _ => {
      if (storedActive is String) storedActive,
      for (final entry in entries)
        if (entry case {'id': final String id}) id,
    }.toList(),
  };
  final byRecency = _ordered(
    accounts: accounts,
    activeAccountId: null,
    recentAccountIds: storedRecent,
  );
  return _StoredRegistry(
    state: _ordered(
      accounts: accounts,
      activeAccountId:
          byRecency.find(storedActive is String ? storedActive : null)?.id ??
          byRecency.recentAccountIds.firstOrNull,
      recentAccountIds: byRecency.recentAccountIds,
    ),
    unreadableEntries: unreadable,
    storedRecentIds: storedRecent,
  );
}

const _linkShareKind = 'link_share';

Map<String, Object?> _encodeAccount(RegisteredAccount entry) {
  final account = entry.account;
  final connection = entry.connection;
  return {
    'id': account.id,
    'server_root': account.serverRoot.toString(),
    // A guest has no `user_id`, so a build before guests fails to read the
    // entry and keeps it as it is, instead of taking it for a user whose
    // tokens are gone.
    if (account.isLinkShare) ...{
      'kind': _linkShareKind,
      'link_share_id': account.linkShareId,
      'project_id': account.projectId,
      'share_name': account.shareName,
    } else ...{
      'user_id': account.userId,
      'username': account.username,
    },
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
  final id = map['id']! as String;
  final serverRoot = Uri.parse(map['server_root']! as String);
  final displayName = map['display_name']! as String;
  final addedAt = DateTime.parse(map['added_at']! as String);
  final needsReauth = map['needs_reauth'] == true;
  return RegisteredAccount(
    account: switch (map['kind']) {
      null => Account(
        id: id,
        serverRoot: serverRoot,
        userId: map['user_id']! as int,
        username: map['username']! as String,
        displayName: displayName,
        addedAt: addedAt,
        needsReauth: needsReauth,
      ),
      _linkShareKind => Account.linkShare(
        id: id,
        serverRoot: serverRoot,
        shareId: map['link_share_id']! as int,
        projectId: map['project_id']! as int,
        shareName: map['share_name'] as String?,
        displayName: displayName,
        addedAt: addedAt,
        needsReauth: needsReauth,
      ),
      final kind => throw FormatException('Unknown account kind $kind'),
    },
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
