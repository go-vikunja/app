import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

@immutable
final class AccountSettingsState {
  const new({
    this.settings = const UserSettings(),
    this.profile,
    this.avatarProvider,
  });

  final UserSettings settings;

  /// Null until a sync of this version or a [AccountSettingsRepository.
  /// refresh] stored it.
  final UserProfile? profile;

  /// Null until [AccountSettingsRepository.refresh] or an avatar change
  /// learned it (the sync does not read it), or for a value this version
  /// does not know.
  final AvatarProvider? avatarProvider;

  @override
  bool operator ==(Object other) =>
      other is AccountSettingsState &&
      other.settings == settings &&
      other.profile == profile &&
      other.avatarProvider == avatarProvider;

  @override
  int get hashCode => Object.hash(settings, profile, avatarProvider);
}

/// The account's own settings on the server (they follow the account to
/// every device), its profile and avatar. Reads come from the database and
/// work offline; every change goes straight to the server, one at a time,
/// and is never queued: it throws the server's `VikunjaFailure` (offline a
/// `NetworkFailure`) with nothing changed here. On success the stored
/// settings and profile take the server's answer at once, the account's
/// name follows in the account list, the user's cached avatars go when the
/// avatar or the name changed, and a sync runs quietly.
abstract interface class AccountSettingsRepository {
  /// The stored state now, then every change.
  Stream<AccountSettingsState> watch();

  /// Reads the settings, the profile and the avatar provider from the
  /// server and stores them.
  Future<void> refresh();

  /// Refusals as `UserSettingsWritePort.update` names them: a timezone the
  /// server cannot load is a `DomainError` code 1025, a default project it
  /// refuses code 3017, a week start or reminder time it cannot take a
  /// `ValidationFailed`. Empty changes send nothing.
  Future<void> update(UserSettingsChanges changes);

  /// One of [AvatarProvider.choices] except [AvatarProvider.upload], which
  /// only [uploadAvatar] sets; anything else is an `ArgumentError` before
  /// any request.
  Future<void> setAvatarProvider(AvatarProvider provider);

  /// Uploads [image] as it is (crop and rotate it first; the server does
  /// neither), which also makes it the avatar. A file that is not a PNG,
  /// JPEG, GIF, BMP, TIFF or WebP image is a `ValidationFailed`, one above
  /// 50 megapixels a `DomainError` code 4032, one above the server's limit
  /// `FileTooLarge`.
  Future<void> uploadAvatar(File image);
}
