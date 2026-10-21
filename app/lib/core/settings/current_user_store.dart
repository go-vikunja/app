import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/settings/user_profile_json.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';

/// Stores the signed-in user as `GET /user` describes them: the user among
/// the known people (without the email), the settings and, when given, the
/// profile and the avatar provider. What is unchanged is not written, so
/// the lists on screen are not reloaded.
Future<void> storeCurrentUser(
  AppDatabase db, {
  required User user,
  required UserSettings settings,
  UserProfile? profile,
  AvatarProvider? avatarProvider,
}) => db.transaction(() async {
  final stored = await db.usersDao.find(user.id);
  if (stored?.username != user.username || stored?.name != user.name) {
    await db.usersDao.upsertAll([
      User(id: user.id, username: user.username, name: user.name),
    ]);
  }
  final state = await db.syncStateDao.readAll();
  final changed = <String, String>{
    SyncStateKeys.userSettings: encodeUserSettings(settings),
    if (profile != null) SyncStateKeys.userProfile: encodeUserProfile(profile),
    SyncStateKeys.avatarProvider: ?avatarProvider?.wireName,
  }..removeWhere((key, value) => state[key] == value);
  if (changed.isNotEmpty) await db.syncStateDao.write(changed);
});
