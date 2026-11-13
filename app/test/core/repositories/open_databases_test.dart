import 'dart:async';
import 'dart:io';
import 'dart:isolate' show ReceivePort, SendPort;
import 'dart:ui' show IsolateNameServer;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/db/account_database_files.dart';
import 'package:vikunja_mobile/core/db/open_account_database.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

import '../../helpers/sync_fakes.dart';

// A file-backed database in its drift_flutter isolate, as on a device; the
// test binding has the IsolateNameServer the isolate registers with.
void main() {
  const accountId = '0123456789abcdef0123456789abcdef';
  late Directory support;
  late PathProviderAccountDatabaseFiles files;
  late OpenDatabases databases;

  OpenDatabases client() => OpenDatabases(
    files,
    open: (accountId, files) => openAccountDatabase(
      accountId: accountId,
      files: files,
      tempDirectoryPath: _constant(support.path),
    ),
  );

  setUp(() {
    support = Directory.systemTemp.createTempSync('vikunja-open-db');
    addTearDown(() => support.delete(recursive: true));
    files = PathProviderAccountDatabaseFiles(
      supportDirectory: _constant(support),
    );
    databases = client();
    addTearDown(forgetSignOutLeftovers);
  });

  SendPort? isolatePort() =>
      IsolateNameServer.lookupPortByName(accountDatabasePortName(accountId));

  test('closing for deletion resolves once the database isolate has closed '
      'sqlite, so the wipe after it deletes a closed database', () async {
    final db = databases.open(accountId);
    await db.syncStateDao.write({'phase': 'tasks'});
    expect(isolatePort(), isNotNull);

    await databases.closeForDeletion(accountId);

    expect(isolatePort(), isNull);
    final path = await files.pathFor(accountId);
    // sqlite removes the WAL when its last connection closes.
    expect(File('$path-wal').existsSync(), isFalse);
    await files.deleteFor(accountId);
    expect(File(path).existsSync(), isFalse);
  });

  test('the same account opens the same database until it is closed', () async {
    final first = databases.open(accountId);
    expect(databases.open(accountId), same(first));

    await databases.close(accountId);

    final second = databases.open(accountId);
    addTearDown(() => databases.close(accountId));
    expect(second, isNot(same(first)));
    expect(await second.syncStateDao.readAll(), isEmpty);
  });

  test('closing what is not open completes at once', () async {
    await databases.close(accountId);
    await databases.closeForDeletion(accountId);
  });

  group('signed out while another isolate holds the database', () {
    const otherAccountId = 'fedcba9876543210fedcba9876543210';
    const poll = Duration(milliseconds: 10);
    late OpenDatabases otherIsolate;

    setUp(() async {
      // Both clients share the one database isolate, as across isolates.
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
      );
      otherIsolate = client();
      addTearDown(() => otherIsolate.close(accountId));
      await databases.open(accountId).syncStateDao.write({'phase': 'tasks'});
      await otherIsolate.open(accountId).syncStateDao.readAll();
      await databases.close(accountId);
    });

    Future<bool> giveUpWaiting() => awaitAccountDatabaseClosed(
      accountId,
      timeout: const Duration(milliseconds: 100),
      pollInterval: poll,
    );

    test('the sign-out gives up waiting, and the next sign-in waits until '
        'that isolate has gone, deletes the files again and opens a new '
        'database', () async {
      final path = await files.pathFor(accountId);
      expect(await giveUpWaiting(), isFalse);
      expect(isolatePort(), isNotNull);

      var settled = false;
      final settling = settleSignedOutDatabases(
        files,
        pollInterval: poll,
      ).whenComplete(() => settled = true);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(settled, isFalse);

      await otherIsolate.close(accountId);
      await settling;

      expect(isolatePort(), isNull);
      expect(File(path).existsSync(), isFalse);
      expect(File('$path-wal').existsSync(), isFalse);
      final fresh = databases.open(accountId);
      addTearDown(() => databases.close(accountId));
      expect(await fresh.syncStateDao.readAll(), isEmpty);
    });

    test('a sign-in gives up after its wait and the account stays a '
        'leftover', () async {
      final deletions = FakeAccountDatabaseFiles();
      await giveUpWaiting();

      await expectLater(
        settleSignedOutDatabases(
          deletions,
          timeout: const Duration(milliseconds: 100),
          pollInterval: poll,
        ),
        throwsA(isA<SignOutStillFinishing>()),
      );
      expect(deletions.deleted, isEmpty);

      await otherIsolate.close(accountId);
      await settleSignedOutDatabases(deletions, pollInterval: poll);
      expect(deletions.deleted, [accountId]);
    });

    test('the guest of another account is not held up by it', () async {
      final deletions = FakeAccountDatabaseFiles();
      await giveUpWaiting();

      await settleSignedOutDatabases(
        deletions,
        accountId: otherAccountId,
        timeout: Duration.zero,
      );

      expect(deletions.deleted, isEmpty);
      await expectLater(
        settleSignedOutDatabases(deletions, timeout: Duration.zero),
        throwsA(isA<SignOutStillFinishing>()),
      );
    });

    test('without a sign-out that gave up, a sign-in neither waits for a '
        'database still open nor deletes anything', () async {
      final deletions = FakeAccountDatabaseFiles();
      expect(isolatePort(), isNotNull);

      await settleSignedOutDatabases(deletions, timeout: Duration.zero);
      await settleSignedOutDatabases(
        deletions,
        accountId: accountId,
        timeout: Duration.zero,
      );

      expect(deletions.deleted, isEmpty);
    });
  });

  group('two sign-ins waiting at once', () {
    const guestId = 'fedcba9876543210fedcba9876543210';
    const poll = Duration(milliseconds: 10);
    final held = <String, ReceivePort>{};

    // A port under the database's name stands in for its isolate, which
    // another part of the app keeps running.
    void hold(String id) {
      final port = ReceivePort();
      held[id] = port;
      IsolateNameServer.registerPortWithName(
        port.sendPort,
        accountDatabasePortName(id),
      );
    }

    void release(String id) {
      IsolateNameServer.removePortNameMapping(accountDatabasePortName(id));
      held.remove(id)?.close();
    }

    setUp(() => addTearDown(() => [...held.keys].forEach(release)));

    Future<void> signOutGivingUp(String id) async {
      hold(id);
      expect(
        await awaitAccountDatabaseClosed(id, timeout: Duration.zero),
        isFalse,
      );
    }

    test('a guest settled and opened again meanwhile is left alone by a '
        "user's sign-in that waits for every leftover", () async {
      final deletions = FakeAccountDatabaseFiles();
      await signOutGivingUp(accountId);
      await signOutGivingUp(guestId);
      final user = settleSignedOutDatabases(
        deletions,
        timeout: const Duration(seconds: 2),
        pollInterval: poll,
      );

      final guest = settleSignedOutDatabases(
        deletions,
        accountId: guestId,
        pollInterval: poll,
      );
      release(guestId);
      await guest;
      expect(deletions.deleted, [guestId]);
      // The guest's new database.
      hold(guestId);

      release(accountId);
      await user;

      expect(deletions.deleted, [guestId, accountId]);
    });

    test(
      'both wait for the same account, whose files are deleted once',
      () async {
        final deletions = _HeldDeletions();
        await signOutGivingUp(guestId);
        final user = settleSignedOutDatabases(deletions, pollInterval: poll);
        final guest = settleSignedOutDatabases(
          deletions,
          accountId: guestId,
          pollInterval: poll,
        );

        release(guestId);
        await Future<void>.delayed(poll * 5);
        deletions.done.complete();
        await Future.wait([user, guest]);

        expect(deletions.deleted, [guestId]);
      },
    );
  });
}

/// Records the deletions, each of which lasts until [done] completes.
final class _HeldDeletions implements AccountDatabaseFiles {
  final List<String> deleted = [];
  final done = Completer<void>();

  @override
  Future<String> pathFor(String accountId) => throw UnimplementedError();

  @override
  Future<Directory> uploadsDirectoryFor(String accountId) =>
      throw UnimplementedError();

  @override
  Future<void> deleteFor(String accountId) async {
    deleted.add(accountId);
    await done.future;
  }
}

// The database options travel to the isolate, so their closures must not
// drag the test's scope (the open databases among it) along.
Future<T> Function() _constant<T>(T value) =>
    () async => value;
