import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/link_share_providers.dart';
import 'package:vikunja_mobile/core/background/background_entry_point.dart';
import 'package:vikunja_mobile/core/notifications/notification_action_handler.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/core/support/session_end_log.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/core/widgets/widget_entry_points.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/guest_fakes.dart';
import '../../helpers/server_connections.dart';

final Provider<Future<void> Function(String, SessionEnded)> _recorder =
    Provider(sessionEndRecorder);

final class _FailingPreferences implements PreferencesStore {
  @override
  Future<String?> getString(String key) async => null;

  @override
  Future<void> setString(String key, String value) async =>
      throw Exception('Preferences full');

  @override
  Future<void> remove(String key) async {}
}

/// Runs [beforeWrite] right before each write, e.g. a sign-out elsewhere.
final class _HookedPreferences implements PreferencesStore {
  new(this._store);

  final PreferencesStore _store;
  Future<void> Function(String key)? beforeWrite;

  @override
  Future<String?> getString(String key) => _store.getString(key);

  @override
  Future<void> setString(String key, String value) async {
    await beforeWrite?.call(key);
    await _store.setString(key, value);
  }

  @override
  Future<void> remove(String key) => _store.remove(key);
}

void main() {
  final at = DateTime.utc(2026, 11, 12, 8, 12);
  late MemoryPreferencesStore preferences;
  late SessionEndLog log;

  setUp(() {
    preferences = MemoryPreferencesStore();
    log = SessionEndLog(preferences, now: () => at);
  });

  test('notes why, where and when a session ended, until it is '
      'forgotten', () async {
    await log.record('a1', SessionEndReason.expired, part: AppPart.app);
    await log.record(
      'a1',
      SessionEndReason.accountLocked,
      part: AppPart.backgroundRun,
    );

    expect(
      await log.read('a1'),
      SessionEndRecord(reason: 'accountLocked', part: 'backgroundRun', at: at),
    );
    expect(await log.read('a2'), isNull);

    await log.forget('a1');

    expect(await log.read('a1'), isNull);
    expect(preferences.values, isEmpty);
  });

  test('stores the reason, the part and the time only', () async {
    await log.record(
      'a1',
      SessionEndReason.expired,
      part: AppPart.backgroundRun,
    );

    expect(jsonDecode(preferences.values[SessionEndLog.keyFor('a1')]!), {
      'reason': 'expired',
      'part': 'backgroundRun',
      'at': '2026-11-12T08:12:00.000Z',
    });
  });

  test('a write that fails is not passed on', () async {
    await SessionEndLog(_FailingPreferences())
        .record('a1', SessionEndReason.expired, part: AppPart.app);
  });

  test('reads a damaged record as none, and the names of a newer version '
      'as they are, letters only', () async {
    final key = SessionEndLog.keyFor('a1');
    for (final damaged in [
      'not json',
      '[]',
      '{"reason": 5, "part": "app", "at": "2026-11-12T08:12:00.000Z"}',
      '{"reason": "expired", "part": "app", "at": "yesterday"}',
      '{"reason": "%%", "part": "app", "at": "2026-11-12T08:12:00.000Z"}',
      '{"reason": "expired", "at": "2026-11-12T08:12:00.000Z"}',
    ]) {
      preferences.values[key] = damaged;
      expect(await log.read('a1'), isNull, reason: damaged);
    }

    preferences.values[key] = jsonEncode({
      'reason': 'serverWiped',
      'part': 'watch App 2 <x>',
      'at': '2026-11-12T09:12:00+01:00',
      'message': 'ignored',
    });
    expect(
      await log.read('a1'),
      SessionEndRecord(reason: 'serverWiped', part: 'watchAppx', at: at),
    );
  });

  group('sessionEndRecorder', () {
    late AuthFakes auth;

    setUp(() => auth = AuthFakes());

    ProviderContainer container({
      List<Override> overrides = const [],
      PreferencesStore? preferences,
    }) {
      final container = ProviderContainer(
        overrides: [
          if (preferences == null)
            ...auth.overrides
          else
            preferencesStoreProvider.overrideWithValue(preferences),
          clockProvider.overrideWithValue(() => at),
          ...overrides,
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<SessionEndRecord?> recorded(String accountId) =>
        SessionEndLog(auth.preferences).read(accountId);

    test("notes an ended session with the container's part, without its "
        'message or code', () async {
      final alice = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: at),
      );
      final record = container(
        overrides: [
          appPartProvider.overrideWithValue(AppPart.notificationAction),
        ],
      ).read(_recorder);

      await record(
        alice.id,
        const SessionEnded(
          SessionEndReason.accountLocked,
          code: 1040,
          message: 'MARKER locked',
        ),
      );

      expect(
        await recorded(alice.id),
        SessionEndRecord(
          reason: 'accountLocked',
          part: 'notificationAction',
          at: at,
        ),
      );
      final stored = auth.preferences.values[SessionEndLog.keyFor(alice.id)]!;
      expect(stored, isNot(contains('MARKER')));
      expect(stored, isNot(contains('1040')));
    });

    test('writes nothing for an account that is not registered', () async {
      final written = <String>[];
      final hooked = _HookedPreferences(auth.preferences)
        ..beforeWrite = (key) async => written.add(key);
      final record = container(preferences: hooked).read(_recorder);

      await record('gone', const SessionEnded(SessionEndReason.expired));

      expect(written, isEmpty);
      expect(await recorded('gone'), isNull);
    });

    test('takes the record back when the account was signed out while it '
        'was written', () async {
      final alice = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: at),
      );
      final hooked = _HookedPreferences(auth.preferences)
        ..beforeWrite = (key) async {
          if (key == SessionEndLog.keyFor(alice.id)) {
            await AccountRegistry(auth.preferences).remove(alice.id);
          }
        };
      final record = container(preferences: hooked).read(_recorder);

      await record(alice.id, const SessionEnded(SessionEndReason.expired));

      expect(await recorded(alice.id), isNull);
    });

    test("every container's session managers note an ended session with "
        'its part', () async {
      for (final (overrides, part) in [
        (const <Override>[], 'app'),
        (backgroundRunOverrides, 'backgroundRun'),
        (notificationActionOverrides, 'notificationAction'),
        (widgetActionOverrides, 'widgetAction'),
      ]) {
        final alice = await auth.seedAccount(
          fullServer270(),
          tokens: issueTokens(issuedAt: at),
        );
        // Tokens that are gone end the session in every container.
        await auth.tokenStore.delete(alice.id);
        final managers = container(overrides: overrides)
            .read(sessionManagersProvider);

        await expectLater(
          managers.forAccount(alice.id).validAccessToken(),
          throwsA(isA<SessionEnded>()),
        );

        expect(
          await recorded(alice.id),
          SessionEndRecord(reason: 'invalidRefreshToken', part: part, at: at),
          reason: part,
        );
      }
    });

    test("a guest's ended session is noted too", () async {
      final guest = await auth.seedGuest(fullServer270(), token: null);
      await auth.linkShareStore.delete(guest.id);
      final sessions = container(overrides: backgroundRunOverrides)
          .read(linkShareSessionsProvider);

      await expectLater(
        sessions.forAccount(guest.id).validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );

      expect(
        await recorded(guest.id),
        SessionEndRecord(reason: 'expired', part: 'backgroundRun', at: at),
      );
    });
  });
}
