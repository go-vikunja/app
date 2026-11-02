import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences_providers.dart';
import 'package:vikunja_mobile/core/repositories/local/local_list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/test_database.dart';

void main() {
  final now = DateTime.utc(2026, 10, 13, 12);
  late AuthFakes auth;
  late Map<String, AppDatabase> databases;
  late ProviderContainer container;

  setUp(() {
    auth = AuthFakes();
    databases = {};
    container = ProviderContainer(
      overrides: [
        ...auth.overrides,
        appDatabaseProvider.overrideWith(
          (ref, accountId) => databases.putIfAbsent(accountId, testDatabase),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('without an account there are none', () async {
    await container.read(accountsProvider.future);

    expect(container.read(listPreferencesProvider), isNull);
  });

  test(
    "they live in the active account's database and follow a switch",
    () async {
      final alice = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now),
      );
      final bob = await auth.seedAccount(
        oauthServer230(),
        tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
        activate: false,
      );
      await container.read(accountsProvider.future);
      container.listen(listPreferencesProvider, (_, _) {});
      const shown = ViewPreferences(showDone: true);

      final forAlice = container.read(listPreferencesProvider);
      expect(forAlice, isA<LocalListPreferences>());
      await forAlice!.saveView('view:70', shown);

      await container.read(accountRegistryProvider).setActive(bob.id);
      await container.read(accountsProvider.future);
      await pumpEventQueue();
      final forBob = container.read(listPreferencesProvider)!;

      expect(await forBob.watchView('view:70').first, isNot(shown));
      expect(
        await LocalListPreferences(databases[alice.id]!)
            .watchView('view:70')
            .first,
        shown,
      );
    },
  );
}
