import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/server_connections.dart';

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
  final at = DateTime.utc(2026, 11, 20, 12);
  late AuthFakes auth;

  setUp(() => auth = AuthFakes());

  SessionDiagnostics diagnostics({PreferencesStore? preferences}) {
    final container = ProviderContainer(
      overrides: [
        if (preferences == null)
          ...auth.overrides
        else
          preferencesStoreProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);
    return container.read(sessionDiagnosticsProvider);
  }

  Iterable<String> sessionNotes() =>
      auth.preferences.values.keys.where((key) => key.startsWith('session.'));

  Future<void> noteEverything(
    SessionDiagnostics notes,
    String accountId,
  ) async {
    await notes.refreshSent(
      accountId,
      token: 'f1',
      part: AppPart.backgroundRun,
      at: at,
    );
    await notes.refreshRefused(accountId, token: 'f1', at: at);
    await notes.noteUnreadable(accountId, at);
    await notes.recordEnd(
      accountId,
      SessionEndDiagnosis(
        at: at,
        cause: SessionEndCause.refreshRejected,
        part: AppPart.backgroundRun,
      ),
    );
  }

  test('the token a refresh rotated away is kept with the end and its '
      'resolution; a record written before it was noted reads without', () {
    final ended = SessionEndDiagnosis(
      at: at,
      cause: SessionEndCause.refreshRejected,
      part: AppPart.app,
      failedToken: 'f2',
      rotatedAwayToken: 'f1',
    );

    final read = SessionEndDiagnosis.tryParse(jsonEncode(ended.toJson()))!;
    expect(read.rotatedAwayToken, 'f1');
    expect(read.failedToken, 'f2');
    expect(read.resolved(SessionEndResolution.restored).rotatedAwayToken, 'f1');

    final older = SessionEndDiagnosis.tryParse(
      jsonEncode({
        'at': at.toIso8601String(),
        'cause': 'refreshRejected',
        'part': 'app',
        'failedToken': 'f2',
      }),
    )!;
    expect(older.failedToken, 'f2');
    expect(older.rotatedAwayToken, isNull);
  });

  test("the app's notes go only to a registered account", () async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: at),
    );
    final written = <String>[];
    final hooked = _HookedPreferences(auth.preferences)
      ..beforeWrite = (key) async => written.add(key);
    final notes = diagnostics(preferences: hooked);

    await noteEverything(notes, 'gone');
    expect(written, isEmpty);
    expect(sessionNotes(), isEmpty);

    await noteEverything(notes, alice.id);
    expect(await notes.lastEnd(alice.id), isNotNull);
    expect(await notes.refreshMarker(alice.id), isNotNull);
  });

  test('a note written while the account was signed out is taken back, as '
      'the wiper has nothing left to forget', () async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: at),
    );
    final hooked = _HookedPreferences(auth.preferences)
      ..beforeWrite = (key) async {
        if (key == SessionDiagnostics.endKey(alice.id)) {
          await AccountRegistry(auth.preferences).remove(alice.id);
        }
      };
    final notes = diagnostics(preferences: hooked);
    await notes.noteUnreadable(alice.id, at);

    await notes.recordEnd(
      alice.id,
      SessionEndDiagnosis(
        at: at,
        cause: SessionEndCause.refreshRejected,
        part: AppPart.backgroundRun,
      ),
    );

    expect(sessionNotes(), isEmpty);
  });
}
