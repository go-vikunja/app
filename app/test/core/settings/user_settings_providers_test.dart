import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/settings/user_settings_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';

import '../../helpers/test_database.dart';

final class _ActiveAccount extends Notifier<String?> {
  @override
  String? build() => null;

  String? get accountId => state;

  set accountId(String? accountId) => state = accountId;
}

final _activeAccount = NotifierProvider<_ActiveAccount, String?>(
  _ActiveAccount.new,
);

void main() {
  late Map<String, AppDatabase> databases;
  late ProviderContainer container;
  late List<UserSettings> seen;

  setUp(() {
    // One database per account, each over its own in-memory connection.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
    );
    databases = {};
    container = ProviderContainer(
      overrides: [
        activeAccountIdProvider.overrideWith(
          (ref) => ref.watch(_activeAccount),
        ),
        appDatabaseProvider.overrideWith(
          (ref, accountId) => databases.putIfAbsent(accountId, testDatabase),
        ),
      ],
    );
    addTearDown(container.dispose);
    seen = [];
  });

  void listen() => container.listen(userSettingsProvider, (_, next) {
    if (next case AsyncData(:final value)) seen.add(value);
  }, fireImmediately: true);

  Future<void> store(String accountId, UserSettings settings) => databases
      .putIfAbsent(accountId, testDatabase)
      .syncStateDao
      .write({SyncStateKeys.userSettings: encodeUserSettings(settings)});

  const todoist = UserSettings(
    defaultProjectId: 4,
    quickAddMagicMode: QuickAddMagicMode.todoist,
  );

  test('nobody signed in: the defaults', () async {
    listen();
    await pumpEventQueue();

    expect(seen, [const UserSettings()]);
  });

  test('before the first sync the defaults, then what it stored', () async {
    container.read(_activeAccount.notifier).accountId = 'a';
    listen();
    await pumpEventQueue();
    expect(seen, [const UserSettings()]);

    await store('a', todoist);
    await pumpEventQueue();

    expect(seen, [const UserSettings(), todoist]);
  });

  test('other writes to the sync state do not emit again', () async {
    await store('a', todoist);
    container.read(_activeAccount.notifier).accountId = 'a';
    listen();
    await pumpEventQueue();

    await databases['a']!.syncStateDao.write({SyncStateKeys.lastId: '7'});
    await store('a', todoist);
    await pumpEventQueue();

    expect(seen, [todoist]);
  });

  test('a display setting changed on the web alone emits again', () async {
    await store('a', todoist);
    container.read(_activeAccount.notifier).accountId = 'a';
    listen();
    await pumpEventQueue();

    const steps = [
      UserSettings(
        defaultProjectId: 4,
        quickAddMagicMode: QuickAddMagicMode.todoist,
        dateDisplay: DateDisplay.dayMonthYear,
      ),
      UserSettings(
        defaultProjectId: 4,
        quickAddMagicMode: QuickAddMagicMode.todoist,
        dateDisplay: DateDisplay.dayMonthYear,
        timeFormat: TimeFormat.twelveHour,
      ),
      UserSettings(
        defaultProjectId: 4,
        quickAddMagicMode: QuickAddMagicMode.todoist,
        dateDisplay: DateDisplay.dayMonthYear,
        timeFormat: TimeFormat.twelveHour,
        colorSchema: ColorSchema.dark,
      ),
      UserSettings(
        defaultProjectId: 4,
        quickAddMagicMode: QuickAddMagicMode.todoist,
        dateDisplay: DateDisplay.dayMonthYear,
        timeFormat: TimeFormat.twelveHour,
        colorSchema: ColorSchema.dark,
        defaultViewKind: ProjectViewKind.table,
      ),
    ];
    for (final step in steps) {
      await store('a', step);
      await pumpEventQueue();
    }

    expect(seen, [todoist, ...steps]);
  });

  test('switching the account switches the settings', () async {
    await store('a', todoist);
    await store('b', const UserSettings(weekStart: 1));
    container.read(_activeAccount.notifier).accountId = 'a';
    listen();
    await pumpEventQueue();

    container.read(_activeAccount.notifier).accountId = 'b';
    await pumpEventQueue();
    container.read(_activeAccount.notifier).accountId = null;
    await pumpEventQueue();

    expect(seen, [
      todoist,
      const UserSettings(weekStart: 1),
      const UserSettings(),
    ]);
  });
}
