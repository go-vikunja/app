import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/repository_helpers.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';

import '../../helpers/test_database.dart';

void main() {
  group('refreshQuietly', () {
    late Logger log;
    late List<LogRecord> records;

    setUp(() {
      hierarchicalLoggingEnabled = true;
      log = Logger('RepositoryHelpersTest')..level = Level.ALL;
      records = [];
      final subscription = log.onRecord.listen(records.add);
      addTearDown(subscription.cancel);
    });

    test('starts the refresh before the first await', () {
      var started = false;
      final done = Completer<void>();

      unawaited(
        refreshQuietly(
          () {
            started = true;
            return done.future;
          },
          log,
          'a change',
        ),
      );

      expect(started, isTrue);
      done.complete();
    });

    test(
      'a failure is swallowed and logged once at fine by its type',
      () async {
        await refreshQuietly(
          () async => throw const FormatException('secret text'),
          log,
          'moving project 7',
        );

        expect(records, hasLength(1));
        expect(records.single.level, Level.FINE);
        expect(
          records.single.message,
          'Sync after moving project 7 failed: FormatException',
        );
      },
    );

    test('a refresh that succeeds logs nothing', () async {
      await refreshQuietly(() async {}, log, 'a change');

      expect(records, isEmpty);
    });
  });

  test('checkedTitle trims and refuses a blank title', () {
    final cases = <String, String?>{
      'Work': 'Work',
      '  Work  ': 'Work',
      '\tA b\n': 'A b',
      '': null,
      '   ': null,
      '\n\t': null,
    };
    for (final MapEntry(key: title, value: expected) in cases.entries) {
      if (expected == null) {
        expect(
          () => checkedTitle(title),
          throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'title')),
          reason: title,
        );
      } else {
        expect(checkedTitle(title), expected, reason: title);
      }
    }
  });

  group('serverTaskId', () {
    late AppDatabase db;

    setUp(() => db = testDatabase());

    test('a server id is itself', () async {
      expect(await serverTaskId(db.tasksDao, 42), 42);
    });

    test('a local id answered by the server is its server id', () async {
      await db
          .into(db.taskIdRemaps)
          .insert(
            TaskIdRemapRow(localId: -3, serverId: 77, at: DateTime.utc(2026)),
          );

      expect(await serverTaskId(db.tasksDao, -3), 77);
    });

    test('a local id not answered yet is not synced yet', () async {
      await expectLater(
        serverTaskId(db.tasksDao, -5),
        throwsA(isA<TaskNotSyncedYet>().having((e) => e.taskId, 'id', -5)),
      );
    });
  });
}
