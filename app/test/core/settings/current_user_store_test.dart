import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/settings/current_user_store.dart';
import 'package:vikunja_mobile/core/settings/user_profile_json.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  const oldSettings = UserSettings(name: 'Alice Example', weekStart: 1);
  const oldProfile = UserProfile(
    id: 7,
    username: 'alice',
    name: 'Alice Example',
  );
  const newSettings = UserSettings(name: 'Alice Renamed', weekStart: 3);
  const newProfile = UserProfile(
    id: 7,
    username: 'alice',
    name: 'Alice Renamed',
  );

  setUp(() => db = testDatabase());

  Future<Map<String, String>> stored() => db.syncStateDao.readAll();

  Future<UserSettings> storedSettings() async =>
      decodeUserSettings((await stored())[SyncStateKeys.userSettings]);

  Future<UserProfile?> storedProfile() async =>
      decodeUserProfile((await stored())[SyncStateKeys.userProfile]);

  test('a read stores its answer only while no account settings change was '
      'counted since it began', () async {
    final before = await accountSettingsChanges(db);
    await storeCurrentUser(
      db,
      user: newProfile.user,
      settings: newSettings,
      profile: newProfile,
      countsAsChange: true,
    );

    expect(
      await storeCurrentUser(
        db,
        user: oldProfile.user,
        settings: oldSettings,
        profile: oldProfile,
        changesAtRead: before,
      ),
      isFalse,
    );
    expect(await storedSettings(), newSettings);
    expect(await storedProfile(), newProfile);
    expect((await db.usersDao.find(7))?.name, 'Alice Renamed');

    expect(
      await storeCurrentUser(
        db,
        user: oldProfile.user,
        settings: oldSettings,
        profile: oldProfile,
        changesAtRead: await accountSettingsChanges(db),
      ),
      isTrue,
    );
    expect(await storedSettings(), oldSettings);
    expect(await storedProfile(), oldProfile);
    expect((await db.usersDao.find(7))?.name, 'Alice Example');
  });

  test('the answer to a change counts it, also when it changes nothing '
      'stored', () async {
    for (var i = 0; i < 2; i++) {
      await storeCurrentUser(
        db,
        user: newProfile.user,
        settings: newSettings,
        profile: newProfile,
        countsAsChange: true,
      );
    }

    expect(await accountSettingsChanges(db), 2);
  });

  test('without a user it stores the settings and the count and leaves the '
      'known people alone', () async {
    await storeCurrentUser(
      db,
      user: null,
      settings: newSettings,
      countsAsChange: true,
    );

    expect(await storedSettings(), newSettings);
    expect(await db.usersDao.find(7), isNull);
    expect(await accountSettingsChanges(db), 1);
  });
}
