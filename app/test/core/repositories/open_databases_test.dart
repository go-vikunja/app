import 'dart:io';
import 'dart:isolate' show SendPort;
import 'dart:ui' show IsolateNameServer;

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/db/account_database_files.dart';
import 'package:vikunja_mobile/core/db/open_account_database.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

// A file-backed database in its drift_flutter isolate, as on a device; the
// test binding has the IsolateNameServer the isolate registers with.
void main() {
  const accountId = '0123456789abcdef0123456789abcdef';
  late Directory support;
  late PathProviderAccountDatabaseFiles files;
  late OpenDatabases databases;

  setUp(() {
    support = Directory.systemTemp.createTempSync('rurana-open-db');
    addTearDown(() => support.delete(recursive: true));
    files = PathProviderAccountDatabaseFiles(
      supportDirectory: _constant(support),
    );
    databases = OpenDatabases(
      files,
      open: (accountId, files) => openAccountDatabase(
        accountId: accountId,
        files: files,
        tempDirectoryPath: _constant(support.path),
      ),
    );
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
}

// The database options travel to the isolate, so their closures must not
// drag the test's scope (the open databases among it) along.
Future<T> Function() _constant<T>(T value) =>
    () async => value;
