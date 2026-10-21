import 'dart:async';
import 'dart:io';

import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository.dart';

final fakeProfileUpdated = DateTime.utc(2026, 10, 20, 9);

const fakeAccountSettingsUser = User(
  id: 7,
  username: 'alice',
  name: 'Alice Example',
);

/// A local user with the initials avatar, as a new account on 2.7.0.
AccountSettingsState fakeAccountSettingsState({
  UserSettings settings = const UserSettings(name: 'Alice Example'),
  bool isLocalUser = true,
  String authProvider = 'local',
  String? pendingEmail,
  AvatarProvider? avatarProvider = AvatarProvider.initials,
}) => AccountSettingsState(
  settings: settings,
  profile: UserProfile(
    id: fakeAccountSettingsUser.id,
    username: fakeAccountSettingsUser.username,
    name: settings.name,
    isLocalUser: isLocalUser,
    authProvider: authProvider,
    pendingEmail: pendingEmail,
    updated: fakeProfileUpdated,
  ),
  avatarProvider: avatarProvider,
);

/// Account settings as the real repository keeps them, in memory: [state]
/// is what [watch] shows, and setting it emits. A success changes it like
/// the server's answer: [update] applies the changes to the settings (an
/// empty timezone stays empty), the profile takes the new name, and every
/// write bumps the profile's `updated` by a second; [setAvatarProvider] and
/// [uploadAvatar] set the avatar provider, `upload` for an upload. [refresh]
/// takes [online] when it is set. A name change is handed to
/// [onNameChanged] (the real repository updates the account list).
///
/// Every call is recorded in [calls] first: `refresh`, `update <changes>`,
/// `setAvatarProvider initials`, `uploadAvatar <file name>`; the changes in
/// [changes] and the files in [uploads]. [beforeCall] can hold one;
/// [failure], or the entry of [failures] for the method name (`update`, …),
/// is thrown instead while set, and nothing changes. Then the real
/// repository's checks: [setAvatarProvider] with `upload` or a sign-in
/// provider is an `ArgumentError`, and empty changes change nothing.
final class FakeAccountSettingsRepository implements AccountSettingsRepository {
  new([AccountSettingsState? state])
    : _state = state ?? fakeAccountSettingsState();

  final _changes = StreamController<AccountSettingsState>.broadcast();
  AccountSettingsState _state;
  final List<String> calls = [];
  final List<UserSettingsChanges> changes = [];
  final List<File> uploads = [];
  Exception? failure;
  final Map<String, Exception> failures = {};
  Future<void> Function(String call)? beforeCall;
  Future<void> Function(String name)? onNameChanged;

  /// Hears every new [state], e.g. to follow it in `userSettingsProvider`.
  void Function(AccountSettingsState state)? onStateChanged;
  AccountSettingsState? online;

  AccountSettingsState get state => _state;

  set state(AccountSettingsState next) {
    _state = next;
    _changes.add(next);
    onStateChanged?.call(next);
  }

  @override
  Stream<AccountSettingsState> watch() async* {
    yield _state;
    yield* _changes.stream;
  }

  @override
  Future<void> refresh() async {
    await _call('refresh', '');
    if (online case final online?) state = online;
  }

  @override
  Future<void> update(UserSettingsChanges changes) async {
    this.changes.add(changes);
    await _call('update', '$changes');
    if (changes.isEmpty) return;
    final settings = changes.applyTo(_state.settings);
    state = AccountSettingsState(
      settings: settings,
      profile: _bumped(name: settings.name),
      avatarProvider: _state.avatarProvider,
    );
    if (changes.name case final name?) await onNameChanged?.call(name);
  }

  @override
  Future<void> setAvatarProvider(AvatarProvider provider) async {
    await _call('setAvatarProvider', provider.wireName);
    if (!AvatarProvider.choices.contains(provider) ||
        provider == AvatarProvider.upload) {
      throw ArgumentError.value(provider, 'provider');
    }
    state = AccountSettingsState(
      settings: _state.settings,
      profile: _bumped(),
      avatarProvider: provider,
    );
  }

  @override
  Future<void> uploadAvatar(File image) async {
    uploads.add(image);
    await _call('uploadAvatar', image.uri.pathSegments.last);
    state = AccountSettingsState(
      settings: _state.settings,
      profile: _bumped(),
      avatarProvider: AvatarProvider.upload,
    );
  }

  Future<void> dispose() => _changes.close();

  UserProfile? _bumped({String? name}) => switch (_state.profile) {
    null => null,
    final profile => UserProfile(
      id: profile.id,
      username: profile.username,
      name: name ?? profile.name,
      isLocalUser: profile.isLocalUser,
      authProvider: profile.authProvider,
      pendingEmail: profile.pendingEmail,
      updated: (profile.updated ?? fakeProfileUpdated).add(
        const Duration(seconds: 1),
      ),
    ),
  };

  Future<void> _call(String method, String detail) async {
    final call = detail.isEmpty ? method : '$method $detail';
    calls.add(call);
    await beforeCall?.call(call);
    if (failures[method] ?? failure case final failure?) throw failure;
  }
}

/// The server side of the account settings: [profile], [settings] and
/// [provider] as the server holds them. [update] applies the changes and
/// answers with the stored state, [setAvatarProvider] and [uploadAvatar]
/// change the provider (an upload to `upload`, its bytes in
/// [uploadedBytes]); every write bumps the profile's `updated` by a second,
/// as the server bumps it on every write to the user, and a name change
/// renames the profile too. Like the real port, a sign-in provider is an
/// `ArgumentError` before any request.
///
/// Every request is logged in [requests] first: `update <changes>`,
/// `avatarProvider`, `setAvatarProvider marble`,
/// `uploadAvatar <file name> <length>`; [failure], or the entry of
/// [failures] for the method name, is thrown instead while set, and nothing
/// changes. [beforeRequest] can hold one.
final class FakeUserSettingsWritePort implements UserSettingsWritePort {
  new({UserProfile? profile, this.settings = const UserSettings()})
    : profile =
          profile ??
          UserProfile(
            id: fakeAccountSettingsUser.id,
            username: fakeAccountSettingsUser.username,
            name: settings.name,
            authProvider: 'local',
            updated: fakeProfileUpdated,
          );

  UserProfile profile;
  UserSettings settings;
  AvatarProvider? provider = AvatarProvider.initials;
  final List<String> requests = [];
  final List<List<int>> uploadedBytes = [];
  final List<Duration?> uploadTimeouts = [];
  Exception? failure;
  final Map<String, Exception> failures = {};
  Future<void> Function(String request)? beforeRequest;

  UserSettingsWriteResult get stored => (profile: profile, settings: settings);

  @override
  Future<UserSettingsWriteResult> update(UserSettingsChanges changes) async {
    await _request('update', '$changes');
    if (!changes.isEmpty) {
      settings = changes.applyTo(settings);
      _bump(name: settings.name);
    }
    return stored;
  }

  @override
  Future<AvatarProvider?> avatarProvider() async {
    await _request('avatarProvider', '');
    return provider;
  }

  @override
  Future<void> setAvatarProvider(AvatarProvider provider) async {
    if (provider.isFromSignIn) throw ArgumentError.value(provider, 'provider');
    await _request('setAvatarProvider', provider.wireName);
    this.provider = provider;
    _bump();
  }

  @override
  Future<void> uploadAvatar({
    required String fileName,
    required Stream<List<int>> bytes,
    required int length,
    Duration? timeout,
  }) async {
    await _request('uploadAvatar', '$fileName $length');
    final received = [await for (final chunk in bytes) ...chunk];
    uploadedBytes.add(received);
    uploadTimeouts.add(timeout);
    provider = AvatarProvider.upload;
    _bump();
  }

  void _bump({String? name}) => profile = UserProfile(
    id: profile.id,
    username: profile.username,
    name: name ?? profile.name,
    isLocalUser: profile.isLocalUser,
    authProvider: profile.authProvider,
    pendingEmail: profile.pendingEmail,
    updated: (profile.updated ?? fakeProfileUpdated).add(
      const Duration(seconds: 1),
    ),
  );

  Future<void> _request(String method, String detail) async {
    final request = detail.isEmpty ? method : '$method $detail';
    requests.add(request);
    await beforeRequest?.call(request);
    if (failures[method] ?? failure case final failure?) throw failure;
  }
}
