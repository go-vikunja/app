import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/server_connections.dart';

RegisteredAccount _entry(
  String id,
  ServerConnection connection, {
  int userId = 7,
  String username = 'alice',
  String displayName = 'Alice Example',
  bool needsReauth = false,
}) => RegisteredAccount(
  account: Account(
    id: id,
    serverRoot: connection.rootUri,
    userId: userId,
    username: username,
    displayName: displayName,
    addedAt: DateTime.utc(2026, 10, 9, 12, 30),
    needsReauth: needsReauth,
  ),
  connection: connection,
);

/// Connections in the app always come from a parsed /info document.
ServerConnection _fromFixture(
  String root,
  Set<ApiVersion> apiVersions,
  String fixture,
) {
  final info = parseServerInfo(
    jsonDecode(
      File('../packages/vikunja_api/test/fixtures/$fixture').readAsStringSync(),
    ) as Map<String, Object?>,
  );
  return ServerConnection(
    rootUri: Uri.parse(root),
    apiVersions: apiVersions,
    info: info,
    capabilities: ServerCapabilities.derive(
      info: info,
      apiVersions: apiVersions,
    ),
  );
}

void main() {
  late MemoryPreferencesStore preferences;
  late AccountRegistry registry;

  setUp(() {
    preferences = MemoryPreferencesStore();
    registry = AccountRegistry(preferences);
  });

  test('starts empty', () async {
    final state = await registry.load();

    expect(state.accounts, isEmpty);
    expect(state.activeAccount, isNull);
  });

  test('a fresh instance restores accounts and their connections', () async {
    final full = _entry(
      'a1',
      _fromFixture('https://tasks.example.org/vikunja', {
        ApiVersion.v1,
        ApiVersion.v2,
      }, 'info_v2_2.7.0.json'),
    );
    final oauth = _entry(
      'b2',
      _fromFixture('http://192.168.1.20:3456', {
        ApiVersion.v1,
      }, 'info_v1_2.3.0.json'),
      userId: 9,
      username: 'bob',
      displayName: 'bob',
      needsReauth: true,
    );
    await registry.upsert(full);
    await registry.upsert(oauth, activate: true);

    final restored = await AccountRegistry(preferences).load();

    expect(restored.activeAccountId, 'b2');
    expect(restored.accounts.map((entry) => entry.account), [
      full.account,
      oauth.account,
    ]);
    for (final (original, copy) in [
      (full, restored.accounts[0]),
      (oauth, restored.accounts[1]),
    ]) {
      final connection = copy.connection;
      expect(connection.rootUri, original.connection.rootUri);
      expect(connection.apiVersions, original.connection.apiVersions);
      expect(
        serverInfoToJson(connection.info),
        serverInfoToJson(original.connection.info),
      );
      expect(
        connection.capabilities.tier,
        original.connection.capabilities.tier,
      );
      expect(connection.capabilities.all, original.connection.capabilities.all);
    }
  });

  test('stores no secrets, only the documented fields', () async {
    await registry.upsert(_entry('a1', fullServer270()));

    final json = jsonDecode(
      preferences.values[AccountRegistry.storageKey]!,
    ) as Map<String, Object?>;
    final account =
        (json['accounts']! as List<Object?>).single! as Map<String, Object?>;

    expect(json['version'], 1);
    expect(json['active_account_id'], 'a1');
    expect(account.keys, {
      'id',
      'server_root',
      'user_id',
      'username',
      'display_name',
      'added_at',
      'needs_reauth',
      'connection',
    });
    expect(account['added_at'], '2026-10-09T12:30:00.000Z');
    expect(account['connection'], containsPair('api_versions', ['v1', 'v2']));
    expect(
      preferences.values[AccountRegistry.storageKey],
      isNot(contains('token')),
    );
  });

  test(
    'the first account becomes active, later ones only on request',
    () async {
      await registry.upsert(_entry('a1', fullServer270()));
      await registry.upsert(_entry('b2', oauthServer230()));

      expect((await registry.load()).activeAccountId, 'a1');

      await registry.upsert(_entry('c3', insecureServer()), activate: true);

      expect((await registry.load()).activeAccountId, 'c3');
    },
  );

  test('upserting the same id replaces the entry in place', () async {
    await registry.upsert(_entry('a1', fullServer270(), needsReauth: true));
    await registry.upsert(_entry('b2', oauthServer230()));

    await registry.upsert(
      _entry('a1', fullServer270(), displayName: 'Alice Renamed'),
    );

    final state = await registry.load();
    expect(state.accounts.map((entry) => entry.id), ['a1', 'b2']);
    expect(state.find('a1')?.account.displayName, 'Alice Renamed');
    expect(state.find('a1')?.account.needsReauth, isFalse);
  });

  test('removing the active account activates the next one', () async {
    await registry.upsert(_entry('a1', fullServer270()));
    await registry.upsert(_entry('b2', oauthServer230()));

    var state = await registry.remove('a1');
    expect(state.accounts.map((entry) => entry.id), ['b2']);
    expect(state.activeAccountId, 'b2');

    state = await registry.remove('b2');
    expect(state.accounts, isEmpty);
    expect(state.activeAccountId, isNull);
  });

  test('marks an account for re-authentication', () async {
    await registry.upsert(_entry('a1', fullServer270()));
    await registry.upsert(_entry('b2', oauthServer230()));

    await registry.markNeedsReauth('b2');

    final state = await AccountRegistry(preferences).load();
    expect(state.find('a1')?.account.needsReauth, isFalse);
    expect(state.find('b2')?.account.needsReauth, isTrue);
  });

  test('setActive ignores unknown ids', () async {
    await registry.upsert(_entry('a1', fullServer270()));

    await registry.setActive('nope');

    expect((await registry.load()).activeAccountId, 'a1');
  });

  test('announces every write', () async {
    final states = <AccountRegistryState>[];
    final subscription = registry.changes.listen(states.add);
    addTearDown(subscription.cancel);

    await registry.upsert(_entry('a1', fullServer270()));
    await registry.markNeedsReauth('a1');
    await registry.remove('a1');
    await pumpEventQueue();

    expect(states, hasLength(3));
    expect(states[1].activeAccount?.account.needsReauth, isTrue);
    expect(states[2].accounts, isEmpty);
  });

  test('concurrent writes of one instance do not lose updates', () async {
    await Future.wait([
      registry.upsert(_entry('a1', fullServer270())),
      registry.upsert(_entry('b2', oauthServer230())),
      registry.upsert(_entry('c3', insecureServer())),
    ]);

    expect((await registry.load()).accounts.map((entry) => entry.id), [
      'a1',
      'b2',
      'c3',
    ]);
  });

  test('leaves unreadable entries out and keeps the rest', () async {
    await registry.upsert(_entry('a1', fullServer270()));
    final json = jsonDecode(
      preferences.values[AccountRegistry.storageKey]!,
    ) as Map<String, Object?>;
    preferences.values[AccountRegistry.storageKey] = jsonEncode({
      ...json,
      'active_account_id': 'gone',
      'accounts': [
        {'id': 'broken'},
        ...json['accounts']! as List<Object?>,
      ],
    });

    final state = await registry.load();

    expect(state.accounts.map((entry) => entry.id), ['a1']);
    expect(state.activeAccountId, 'a1');
  });

  test('an unreadable registry starts empty instead of failing', () async {
    preferences.values[AccountRegistry.storageKey] = '{not json';

    expect((await registry.load()).accounts, isEmpty);
  });

  group('recency', () {
    Map<String, Object?> storedJson() =>
        jsonDecode(preferences.values[AccountRegistry.storageKey]!)
            as Map<String, Object?>;

    List<String> idsOf(Iterable<RegisteredAccount> entries) => [
      for (final entry in entries) entry.id,
    ];

    Future<void> seedThree() async {
      await registry.upsert(_entry('a1', fullServer270()));
      await registry.upsert(_entry('b2', oauthServer230(), userId: 8));
      await registry.upsert(_entry('c3', insecureServer(), userId: 9));
    }

    test('activating moves an account to the front, and the stored order '
        'stays as added', () async {
      await seedThree();
      expect(idsOf((await registry.load()).accountsByRecency), [
        'a1',
        'b2',
        'c3',
      ]);

      await registry.setActive('c3');
      await registry.upsert(
        _entry('b2', oauthServer230(), userId: 8),
        activate: true,
      );

      final state = await AccountRegistry(preferences).load();
      expect(state.activeAccountId, 'b2');
      expect(idsOf(state.accountsByRecency), ['b2', 'c3', 'a1']);
      expect(state.recentAccountIds, ['b2', 'c3', 'a1']);
      expect(idsOf(state.accounts), ['a1', 'b2', 'c3']);
      expect(storedJson()['recent_account_ids'], ['b2', 'c3', 'a1']);
    });

    test('an upsert without activation keeps the place, and a new account '
        'comes last', () async {
      await seedThree();
      await registry.setActive('c3');

      await registry.upsert(
        _entry('a1', fullServer270(), displayName: 'Alice Renamed'),
      );
      await registry.upsert(_entry('d4', fullServer270(), userId: 10));

      expect(idsOf((await registry.load()).accountsByRecency), [
        'c3',
        'a1',
        'b2',
        'd4',
      ]);
    });

    test('removing the active account activates the most recently active '
        'of the rest, not the first stored one', () async {
      await seedThree();
      await registry.setActive('c3');
      await registry.setActive('a1');

      final state = await registry.remove('a1');

      expect(state.activeAccountId, 'c3');
      expect(idsOf(state.accountsByRecency), ['c3', 'b2']);
      expect((await AccountRegistry(preferences).load()).activeAccountId, 'c3');
      expect(storedJson()['recent_account_ids'], ['c3', 'b2']);
    });

    test('removing an inactive account leaves the active one', () async {
      await seedThree();
      await registry.setActive('b2');

      final state = await registry.remove('c3');

      expect(state.activeAccountId, 'b2');
      expect(idsOf(state.accountsByRecency), ['b2', 'a1']);
      expect(storedJson()['recent_account_ids'], ['b2', 'a1']);
    });

    test('a registry stored without recency reads as the stored order with '
        'the active account first', () async {
      await seedThree();
      final json = storedJson()
        ..remove('recent_account_ids')
        ..['active_account_id'] = 'b2';
      preferences.values[AccountRegistry.storageKey] = jsonEncode(json);

      final state = await registry.load();
      expect(state.activeAccountId, 'b2');
      expect(idsOf(state.accountsByRecency), ['b2', 'a1', 'c3']);

      final afterRemove = await registry.remove('b2');
      expect(afterRemove.activeAccountId, 'a1');
      expect(storedJson()['recent_account_ids'], ['a1', 'c3']);
    });

    test('ids that are unknown or no strings are skipped, and accounts the '
        'recency misses come last in stored order', () async {
      await seedThree();
      preferences.values[AccountRegistry.storageKey] = jsonEncode({
        ...storedJson(),
        'active_account_id': 'c3',
        'recent_account_ids': ['gone', 42, 'b2'],
      });

      expect(idsOf((await registry.load()).accountsByRecency), [
        'c3',
        'b2',
        'a1',
      ]);
    });

    test('a recency that is not a list reads like none', () async {
      await seedThree();
      preferences.values[AccountRegistry.storageKey] = jsonEncode({
        ...storedJson(),
        'active_account_id': 'c3',
        'recent_account_ids': 'b2',
      });

      expect(idsOf((await registry.load()).accountsByRecency), [
        'c3',
        'a1',
        'b2',
      ]);
    });

    test('an unreadable entry keeps its place in the accounts and the '
        'recency while the others move', () async {
      await seedThree();
      await registry.setActive('c3');
      final json = storedJson();
      final accounts = json['accounts']! as List<Object?>;
      final broken = accounts[1]! as Map<String, Object?>;
      (broken['connection']! as Map<String, Object?>)['api_versions'] =
          <Object?>[];
      json['recent_account_ids'] = ['c3', 'b2', 'a1'];
      preferences.values[AccountRegistry.storageKey] = jsonEncode(json);

      final state = await registry.setActive('a1');

      expect(idsOf(state.accounts), ['a1', 'c3']);
      expect(idsOf(state.accountsByRecency), ['a1', 'c3']);
      final stored = storedJson();
      expect(
        [
          for (final entry in stored['accounts']! as List<Object?>)
            (entry! as Map<String, Object?>)['id'],
        ],
        ['a1', 'b2', 'c3'],
      );
      expect((stored['accounts']! as List<Object?>)[1], equals(broken));
      expect(stored['recent_account_ids'], ['a1', 'b2', 'c3']);
    });

    test('an unreadable active entry hands over to the most recent readable '
        'account', () async {
      await seedThree();
      await registry.setActive('c3');
      final json = storedJson();
      final accounts = json['accounts']! as List<Object?>;
      ((accounts[2]! as Map<String, Object?>)['connection']!
              as Map<String, Object?>)['api_versions'] =
          <Object?>[];
      json['recent_account_ids'] = ['c3', 'b2', 'a1'];
      preferences.values[AccountRegistry.storageKey] = jsonEncode(json);

      final state = await registry.load();

      expect(state.activeAccountId, 'b2');
      expect(idsOf(state.accountsByRecency), ['b2', 'a1']);
    });

    test('a state built without recency lists the active account first, then '
        'the stored order', () {
      final state = AccountRegistryState(
        accounts: [
          _entry('a1', fullServer270()),
          _entry('b2', oauthServer230()),
          _entry('c3', insecureServer()),
        ],
        activeAccountId: 'b2',
      );

      expect(idsOf(state.accountsByRecency), ['b2', 'a1', 'c3']);
    });
  });

  group('entries this version cannot read', () {
    Map<String, Object?> storedJson() =>
        jsonDecode(preferences.values[AccountRegistry.storageKey]!)
            as Map<String, Object?>;

    List<Object?> storedAccounts() =>
        storedJson()['accounts']! as List<Object?>;

    /// Stores [a1] readable next to an entry whose connection lost its API
    /// versions, as a stricter future parser might see it.
    Future<Map<String, Object?>> seedWithUnreadable({String id = 'b2'}) async {
      await registry.upsert(_entry(id, oauthServer230(), userId: 8));
      await registry.upsert(_entry('a1', fullServer270()), activate: true);
      final json = storedJson();
      final accounts = json['accounts']! as List<Object?>;
      final broken = accounts.first! as Map<String, Object?>;
      (broken['connection']! as Map<String, Object?>)['api_versions'] =
          <Object?>[];
      preferences.values[AccountRegistry.storageKey] = jsonEncode(json);
      return broken;
    }

    test('survive other writes unchanged', () async {
      final broken = await seedWithUnreadable();

      await registry.upsert(_entry('c3', insecureServer(), userId: 9));
      await registry.markNeedsReauth('a1');

      final state = await registry.load();
      expect(state.accounts.map((entry) => entry.id), ['a1', 'c3']);
      expect(state.find('a1')?.account.needsReauth, isTrue);
      expect(storedAccounts(), hasLength(3));
      expect(storedAccounts(), contains(equals(broken)));
    });

    test('are replaced by a readable entry with the same id', () async {
      await seedWithUnreadable();

      await registry.upsert(_entry('b2', oauthServer230(), userId: 8));

      expect(storedAccounts(), hasLength(2));
      expect(
        (await registry.load()).accounts.map((entry) => entry.id),
        unorderedEquals(['a1', 'b2']),
      );
    });

    test('a registry that cannot be read at all is kept aside before the '
        'first write replaces it', () async {
      preferences.values[AccountRegistry.storageKey] = '{not json';

      await registry.upsert(_entry('a1', fullServer270()));

      expect(
        preferences.values[AccountRegistry.unreadableStorageKey],
        '{not json',
      );
      expect((await registry.load()).accounts, hasLength(1));
    });
  });
}
