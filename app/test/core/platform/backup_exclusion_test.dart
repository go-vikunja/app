import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/platform/backup_exclusion.dart';

void main() {
  late _RecordingExclusion exclusion;
  late List<LogRecord> records;

  setUp(() {
    exclusion = _RecordingExclusion();
    records = [];
    final previousLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    final subscription = Logger.root.onRecord.listen(records.add);
    addTearDown(() async {
      Logger.root.level = previousLevel;
      await subscription.cancel();
    });
  });

  Future<Directory> support() async => Directory('/support-marker');

  test("excludes the accounts' folder and the widgets' App Group "
      'folder', () async {
    await excludeAppDataFromBackup(
      exclusion: exclusion,
      supportDirectory: support,
      widgetsDirectory: () async => Directory('/group-marker/widgets'),
    );

    expect(exclusion.calls.single, [
      '/support-marker/accounts',
      '/group-marker/widgets',
    ]);
  });

  test('without the App Group (an unsigned build) only the accounts', () async {
    await excludeAppDataFromBackup(
      exclusion: exclusion,
      supportDirectory: support,
      widgetsDirectory: () async => null,
    );

    expect(exclusion.calls.single, ['/support-marker/accounts']);
  });

  test('a failure is logged by its type, never with a path', () async {
    exclusion.failure = const FileSystemException(
      'denied',
      '/support-marker/accounts',
    );

    await excludeAppDataFromBackup(
      exclusion: exclusion,
      supportDirectory: support,
      widgetsDirectory: () async => null,
    );

    expect(records.single.level, Level.WARNING);
    expect(records.single.message, contains('FileSystemException'));
    expect(records.single.message, isNot(contains('marker')));
    expect(records.single.error, isNull);
  });
}

final class _RecordingExclusion implements BackupExclusion {
  final calls = <List<String>>[];
  Exception? failure;

  @override
  Future<void> exclude(List<String> paths) async {
    calls.add(paths);
    if (failure case final failure?) throw failure;
  }
}
