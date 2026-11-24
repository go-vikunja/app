import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/settings/user_profile_json.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';

/// [SyncStateKeys.accountSettingsChanges] as stored; 0 before the first.
Future<int> accountSettingsChanges(AppDatabase db) async =>
    _changesIn(await db.syncStateDao.readAll());

int _changesIn(Map<String, String> state) =>
    int.tryParse(state[SyncStateKeys.accountSettingsChanges] ?? '') ?? 0;

/// Stores the signed-in user as `GET /user` describes them, or as a change
/// the server took left them: the user among the known people (without the
/// email) when given, the settings and, when given, the profile and the
/// avatar provider. What is unchanged is not written, so the lists on
/// screen are not reloaded.
///
/// A read that began when [accountSettingsChanges] was [changesAtRead]
/// stores nothing once a change was counted since, as the server may have
/// answered it before that change, and returns false. [countsAsChange]
/// stores the answer to a change the server took and counts it in the same
/// transaction.
Future<bool> storeCurrentUser(
  AppDatabase db, {
  required User? user,
  required UserSettings settings,
  UserProfile? profile,
  AvatarProvider? avatarProvider,
  int? changesAtRead,
  bool countsAsChange = false,
}) => db.transaction(() async {
  final state = await db.syncStateDao.readAll();
  final changes = _changesIn(state);
  if (changesAtRead != null && changes != changesAtRead) return false;
  if (user != null) {
    final stored = await db.usersDao.find(user.id);
    if (stored?.username != user.username || stored?.name != user.name) {
      await db.usersDao.upsertAll([
        User(id: user.id, username: user.username, name: user.name),
      ]);
    }
  }
  final changed = <String, String>{
    SyncStateKeys.userSettings: encodeUserSettings(settings),
    if (profile != null) SyncStateKeys.userProfile: encodeUserProfile(profile),
    SyncStateKeys.avatarProvider: ?avatarProvider?.wireName,
  }..removeWhere((key, value) => state[key] == value);
  if (countsAsChange) {
    changed[SyncStateKeys.accountSettingsChanges] = '${changes + 1}';
  }
  if (changed.isNotEmpty) await db.syncStateDao.write(changed);
  return true;
});
