import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_record.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_theme.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository.dart';

import '../../helpers/account_settings_fakes.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/server_connections.dart';

RegisteredAccount _user({bool needsReauth = false}) => RegisteredAccount(
  account: Account(
    id: 'alice',
    serverRoot: Uri.parse('https://vikunja.example.com'),
    userId: 7,
    username: 'alice',
    displayName: 'Alice Example',
    addedAt: DateTime.utc(2026, 11),
    needsReauth: needsReauth,
  ),
  connection: fullServer270(),
);

final _guest = RegisteredAccount(
  account: Account.linkShare(
    id: 'guest',
    serverRoot: Uri.parse('https://vikunja.example.com'),
    shareId: 3,
    projectId: 12,
    displayName: 'Shared project',
    addedAt: DateTime.utc(2026, 11),
  ),
  connection: fullServer270(),
);

void main() {
  late MemoryPreferencesStore preferences;
  late FakeAccountSettingsRepository repository;

  setUp(() {
    preferences = MemoryPreferencesStore();
    repository = FakeAccountSettingsRepository();
  });

  Future<void> remember(String theme, {String? server}) =>
      rememberPreviousAppTheme(
        preferences,
        theme: theme,
        server: Uri.parse(server ?? 'https://vikunja.example.com'),
      );

  bool isPending() => preferences.values.containsKey(previousAppThemeKey);

  Future<void> carryOver({
    RegisteredAccount? entry,
    bool noEntry = false,
    AccountSettingsRepository? repositoryOverride,
    bool noRepository = false,
  }) => carryOverPreviousAppTheme(
    preferences: preferences,
    entry: noEntry ? null : entry ?? _user(),
    repository: noRepository ? null : repositoryOverride ?? repository,
  );

  test('a pending dark becomes the color scheme of an account that follows '
      'the system, once', () async {
    await remember('dark');

    await carryOver();

    expect(repository.changes, [
      const UserSettingsChanges(colorSchema: ColorSchema.dark),
    ]);
    expect(isPending(), isFalse);

    await carryOver();
    expect(repository.changes, hasLength(1));
  });

  test('a pending light becomes light', () async {
    await remember('light');

    await carryOver();

    expect(repository.changes, [
      const UserSettingsChanges(colorSchema: ColorSchema.light),
    ]);
  });

  test('a scheme chosen on the web wins, and the pending value goes', () async {
    await remember('dark');
    repository.state = fakeAccountSettingsState(
      settings: const UserSettings(colorSchema: ColorSchema.light),
    );

    await carryOver();

    expect(repository.calls, isEmpty);
    expect(isPending(), isFalse);
  });

  for (final (name, entry) in [
    ('a guest', _guest),
    ('an account that has to sign in again', _user(needsReauth: true)),
  ]) {
    test('$name leaves it pending', () async {
      await remember('dark');

      await carryOver(entry: entry);

      expect(repository.calls, isEmpty);
      expect(isPending(), isTrue);
    });
  }

  test('no account or no repository leaves it pending', () async {
    await remember('dark');

    await carryOver(noEntry: true);
    await carryOver(noRepository: true);

    expect(repository.calls, isEmpty);
    expect(isPending(), isTrue);
  });

  test('settings that are not synced within the timeout leave it pending, '
      'and the wait ends', () async {
    await remember('dark');
    repository.state = const AccountSettingsState();
    final watching = _WatchedRepository(repository);

    await carryOverPreviousAppTheme(
      preferences: preferences,
      entry: _user(),
      repository: watching,
      settingsTimeout: const Duration(milliseconds: 50),
    );

    expect(repository.calls, isEmpty);
    expect(isPending(), isTrue);
    expect(watching.cancelled, isTrue);
  });

  test('settings synced while waiting are used', () async {
    await remember('dark');
    final synced = repository.state;
    repository.state = const AccountSettingsState();

    final carried = carryOver();
    await pumpEventQueue();
    repository.state = synced;
    await carried;

    expect(repository.changes, [
      const UserSettingsChanges(colorSchema: ColorSchema.dark),
    ]);
  });

  test('a save that fails is not tried again and does not throw', () async {
    await remember('dark');
    repository.failures['update'] = Exception('offline');

    await carryOver();

    expect(repository.calls, hasLength(1));
    expect(isPending(), isFalse);
  });

  for (final (name, stored) in [
    (
      'a theme other than light or dark',
      '{"theme":"system","server":'
          '"https://vikunja.example.com"}',
    ),
    ('a theme without its server', 'dark'),
    ('a server without a host', '{"theme":"dark","server":"vikunja"}'),
  ]) {
    test('$name goes without a save', () async {
      preferences.values[previousAppThemeKey] = stored;

      await carryOver();

      expect(repository.calls, isEmpty);
      expect(isPending(), isFalse);
    });
  }

  test('an account on another server, such as the shared account of the '
      "public demo, leaves it pending for one on the previous app's "
      'server', () async {
    await remember('dark', server: 'https://tasks.example.org');

    await carryOver();

    expect(repository.calls, isEmpty);
    expect(isPending(), isTrue);
  });

  test('without a pending value the repository is not touched', () async {
    final watching = _WatchedRepository(repository);

    await carryOver(repositoryOverride: watching);

    expect(watching.watched, isFalse);
    expect(repository.calls, isEmpty);
  });
}

/// Records whether [watch] was listened to and cancelled.
final class _WatchedRepository implements AccountSettingsRepository {
  new(this._inner);

  final FakeAccountSettingsRepository _inner;
  bool watched = false;
  bool cancelled = false;

  @override
  Stream<AccountSettingsState> watch() {
    watched = true;
    late StreamSubscription<AccountSettingsState> subscription;
    late StreamController<AccountSettingsState> controller;
    controller = StreamController(
      onListen: () => subscription = _inner.watch().listen(
        controller.add,
        onError: controller.addError,
      ),
      onCancel: () {
        cancelled = true;
        return subscription.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<void> refresh() => _inner.refresh();

  @override
  Future<void> update(UserSettingsChanges changes) => _inner.update(changes);

  @override
  Future<void> setAvatarProvider(AvatarProvider provider) =>
      _inner.setAvatarProvider(provider);

  @override
  Future<void> uploadAvatar(File image) => _inner.uploadAvatar(image);
}
