import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

// Pins the finding behind SessionManager's refresh design: an exclusive
// RandomAccessFile lock does not keep a second isolate of the same process
// out, because POSIX record locks belong to the process. If this test starts
// failing, the Dart runtime changed and a file lock could serialise refreshes
// across isolates after all.
void main() {
  test('a file lock held by one isolate does not block another isolate of '
      'the same process', () async {
    final directory = Directory.systemTemp.createTempSync('refresh_lock');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}/account.lock';
    final held = await File(path).open(mode: FileMode.append);
    addTearDown(held.close);
    await held.lock(FileLock.blockingExclusive);

    final acquiredElsewhere = await Isolate.run(() async {
      final file = await File(path).open(mode: FileMode.append);
      try {
        await file.lock();
        return true;
      } on FileSystemException {
        return false;
      } finally {
        await file.close();
      }
    });

    expect(acquiredElsewhere, isTrue);
  });
}
