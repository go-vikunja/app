import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/upload_policy.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_helpers.dart';
import 'package:vikunja_mobile/core/settings/current_user_store.dart';
import 'package:vikunja_mobile/core/settings/user_profile_json.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';

final _log = Logger('AccountSettings');

/// What a change did to the user's avatar, for the avatar caches.
enum OwnAvatarChange {
  changed,

  /// The write bumped the user's `updated` but left the avatar.
  unchanged,

  /// Read from the server; it may have changed elsewhere.
  unknown,
}

typedef OwnAvatarNote = void Function(
  UserProfile profile,
  OwnAvatarChange change,
);

/// The account settings straight to the server, stored once answered; see
/// [AccountSettingsRepository]. Writes always start from the server's own
/// copy (`UserSettingsWritePort`), never from the stored settings, which
/// keep only what the app models.
final class LocalAccountSettingsRepository
    implements AccountSettingsRepository {
  new({
    required this._db,
    required this._sync,
    required this._write,
    required this._currentUser,
    required this._onName,
    required this._noteAvatar,
  });

  final AppDatabase _db;
  final SyncEngine _sync;
  final UserSettingsWritePort _write;
  final Future<UserWithProfile> Function() _currentUser;
  final Future<void> Function(String name) _onName;
  final OwnAvatarNote _noteAvatar;
  Future<void> _queue = Future.value();

  static const Set<String> _keys = {
    SyncStateKeys.userSettings,
    SyncStateKeys.userProfile,
    SyncStateKeys.avatarProvider,
  };

  @override
  Stream<AccountSettingsState> watch() => _db.syncStateDao
      .watchValues(_keys)
      .map(
        (values) => AccountSettingsState(
          settings: decodeUserSettings(values[SyncStateKeys.userSettings]),
          profile: decodeUserProfile(values[SyncStateKeys.userProfile]),
          avatarProvider: AvatarProvider.fromWire(
            values[SyncStateKeys.avatarProvider],
          ),
        ),
      )
      .distinct();

  @override
  Future<void> refresh() => _serialized(() async {
    final (user: _, :profile, :settings) = await _currentUser();
    final provider = await _write.avatarProvider();
    await _store(
      profile,
      settings,
      OwnAvatarChange.unknown,
      avatarProvider: provider,
    );
  });

  @override
  Future<void> update(UserSettingsChanges changes) async {
    if (changes.isEmpty) return;
    await _serialized(() async {
      final before = await _storedProfile();
      final answer = await _write.update(changes);
      if (answer == null) {
        await _storeWithoutReadBack(changes);
        return;
      }
      final (:profile, :settings) = answer;
      // The answer's `updated` also covers changes made elsewhere since the
      // caches last heard one, e.g. what a background sync stored.
      if (changes.name == null && before != null) {
        _noteAvatar(before, OwnAvatarChange.unknown);
      }
      await _store(
        profile,
        settings,
        changes.name == null
            ? OwnAvatarChange.unchanged
            : OwnAvatarChange.changed,
        countsAsChange: true,
      );
    });
    _settle('Updated settings: $changes');
  }

  @override
  Future<void> setAvatarProvider(AvatarProvider provider) async {
    if (!AvatarProvider.choices.contains(provider) ||
        provider == AvatarProvider.upload) {
      throw ArgumentError.value(provider, 'provider');
    }
    await _serialized(() async {
      await _write.setAvatarProvider(provider);
      await _storeAvatarChange(provider);
    });
    _settle('Avatar provider: ${provider.wireName}');
  }

  @override
  Future<void> uploadAvatar(File image) async {
    await _serialized(() async {
      final length = await image.length();
      await _write.uploadAvatar(
        fileName: p.basename(image.path),
        bytes: image.openRead(),
        length: length,
        timeout: uploadTimeoutFor(length),
      );
      await _storeAvatarChange(AvatarProvider.upload);
    });
    _settle('Uploaded an avatar');
  }

  /// The change is made, so a read-back that fails is no failure: the
  /// caches go now, and the quiet sync stores the profile.
  Future<void> _storeAvatarChange(AvatarProvider provider) async {
    try {
      final (user: _, :profile, :settings) = await _currentUser();
      await _store(
        profile,
        settings,
        OwnAvatarChange.changed,
        avatarProvider: provider,
        countsAsChange: true,
      );
    } on VikunjaFailure catch (failure) {
      _log.info('Reading back the avatar change failed: $failure');
      await _db.syncStateDao.write({
        SyncStateKeys.avatarProvider: provider.wireName,
      });
      final stored = await _storedProfile();
      if (stored != null) _noteAvatar(stored, OwnAvatarChange.changed);
    }
  }

  /// The server took [changes], so a read-back that fails is no failure:
  /// they are applied to what is stored, and the quiet sync stores the
  /// server's own copy.
  Future<void> _storeWithoutReadBack(UserSettingsChanges changes) async {
    final name = changes.name;
    await _db.transaction(() async {
      final stored = await _db.syncStateDao.readAll();
      final settings = changes.applyTo(
        decodeUserSettings(stored[SyncStateKeys.userSettings]),
      );
      final profile = switch (decodeUserProfile(
        stored[SyncStateKeys.userProfile],
      )) {
        final profile? when name != null => _renamed(profile, name),
        final profile => profile,
      };
      if (profile != null && name != null) {
        _noteAvatar(profile, OwnAvatarChange.changed);
      }
      await storeCurrentUser(
        _db,
        user: profile?.user,
        settings: settings,
        profile: profile,
        countsAsChange: true,
      );
    });
    if (name != null) await _onName(name);
  }

  Future<UserProfile?> _storedProfile() async => decodeUserProfile(
    (await _db.syncStateDao.readAll())[SyncStateKeys.userProfile],
  );

  /// The caches hear of the change before the profile is stored, which
  /// they also watch, so they evict once. The answer to a change counts as
  /// one, so a sync that began reading the user before it, here or in a
  /// background run, does not store its older answer over this one.
  Future<void> _store(
    UserProfile profile,
    UserSettings settings,
    OwnAvatarChange change, {
    AvatarProvider? avatarProvider,
    bool countsAsChange = false,
  }) async {
    _noteAvatar(profile, change);
    await storeCurrentUser(
      _db,
      user: profile.user,
      settings: settings,
      profile: profile,
      avatarProvider: avatarProvider,
      countsAsChange: countsAsChange,
    );
    await _onName(profile.name);
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  void _settle(String done) {
    _log.fine(done);
    unawaited(
      refreshQuietly(_sync.refreshAfterWrite, _log, 'a settings change'),
    );
  }
}

UserProfile _renamed(UserProfile profile, String name) => UserProfile(
  id: profile.id,
  username: profile.username,
  name: name,
  isLocalUser: profile.isLocalUser,
  authProvider: profile.authProvider,
  pendingEmail: profile.pendingEmail,
  updated: profile.updated,
  deletionScheduledAt: profile.deletionScheduledAt,
);
