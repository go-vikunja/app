import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_mobile/core/db/account_database_files.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';

void main() {
  late Directory support;
  late PathProviderAccountDatabaseFiles files;
  const accountId = '0123456789abcdef0123456789abcdef';

  setUp(() {
    support = Directory.systemTemp.createTempSync('rurana-db-files');
    addTearDown(() => support.delete(recursive: true));
    files = PathProviderAccountDatabaseFiles(
      supportDirectory: () async => support,
    );
  });

  test(
    'the path is per account under the support directory and exists',
    () async {
      final path = await files.pathFor(accountId);

      expect(path, p.join(support.path, 'accounts', accountId, 'vikunja.db'));
      expect(Directory(p.dirname(path)).existsSync(), isTrue);
      expect(
        await files.pathFor('fedcba9876543210fedcba9876543210'),
        isNot(path),
      );
    },
  );

  test('only account ids become paths', () async {
    await expectLater(files.pathFor('../other'), throwsArgumentError);
    await expectLater(files.deleteFor(''), throwsArgumentError);
  });

  test(
    'deleting removes the database with its WAL and journal files',
    () async {
      final path = await files.pathFor(accountId);
      final db = AppDatabase(
        NativeDatabase(
          File(path),
          setup: (raw) => raw.execute('PRAGMA journal_mode = WAL'),
        ),
      );
      await db.syncStateDao.write({'phase': 'tasks'});
      await db.close();
      // A clean close removes the WAL; a killed app leaves all three.
      for (final suffix in ['-wal', '-shm', '-journal']) {
        File('$path$suffix').writeAsStringSync('');
      }

      await files.deleteFor(accountId);

      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        expect(File('$path$suffix').existsSync(), isFalse, reason: suffix);
      }
      expect(Directory(p.dirname(path)).existsSync(), isFalse);
    },
  );

  test(
    'the uploads folder sits beside the database and goes with it',
    () async {
      final path = await files.pathFor(accountId);
      final uploads = await files.uploadsDirectoryFor(accountId);
      expect(uploads.path, p.join(p.dirname(path), 'uploads'));
      File(p.join(uploads.path, 'a' * 32)).createSync(recursive: true);
      File(path).writeAsStringSync('');

      await files.deleteFor(accountId);

      expect(uploads.existsSync(), isFalse);
      expect(Directory(p.dirname(path)).existsSync(), isFalse);
    },
  );

  test('deleting what does not exist is fine', () async {
    await files.deleteFor(accountId);

    expect(Directory(p.join(support.path, 'accounts')).existsSync(), isFalse);
  });
}
