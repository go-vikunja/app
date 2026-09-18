import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/network/token_lock.dart';

/// `client_test.dart` exercises the token-refresh flow that *uses* the lock.
/// These tests pin the lock's own contract: serialisation, release on error,
/// and stale-lock recovery.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('vikunja_token_lock_test');
    TokenLock.setLockDirectory(tempDir);
  });

  tearDown(() async {
    TokenLock.setLockDirectory(null);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('returns the callback result', () async {
    final result = await TokenLock.synchronized(() async => 42);

    expect(result, 42);
  });

  test('runs overlapping callbacks one at a time', () async {
    final events = <String>[];

    Future<void> section(String name, Duration hold) =>
        TokenLock.synchronized(() async {
          events.add('enter-$name');
          await Future.delayed(hold);
          events.add('exit-$name');
        });

    await Future.wait([
      section('a', const Duration(milliseconds: 40)),
      section('b', Duration.zero),
    ]);

    // No 'enter' may appear between another section's enter and exit.
    expect(events, ['enter-a', 'exit-a', 'enter-b', 'exit-b']);
  });

  test('rethrows a callback failure and still releases the lock', () async {
    await expectLater(
      TokenLock.synchronized(() async => throw StateError('inner failure')),
      throwsA(isA<StateError>()),
    );

    // If the lock leaked, this second acquisition would time out.
    expect(await TokenLock.synchronized(() async => 'free'), 'free');
  });

  test('leaves no lock or temp files behind', () async {
    await TokenLock.synchronized(() async => null);

    expect(tempDir.listSync(), isEmpty);
  });

  test('breaks a stale lock left by a dead process', () async {
    final lockPath = '${tempDir.path}/vikunja_token_refresh.lock';
    final orphan = File('${tempDir.path}/orphan')..writeAsStringSync('dead');
    await Link(lockPath).create(orphan.path);
    // The staleness check stats through the symlink, so the *target* mtime is
    // what ages out. Backdate it past the 30s threshold.
    orphan.setLastModifiedSync(DateTime(2000));

    expect(await TokenLock.synchronized(() async => 'recovered'), 'recovered');
  });
}
