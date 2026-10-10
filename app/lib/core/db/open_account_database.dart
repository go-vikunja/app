import 'dart:async';
import 'dart:ui' show IsolateNameServer;

import 'package:drift_flutter/drift_flutter.dart';
import 'package:logging/logging.dart';
import 'package:sqlite3/common.dart';
import 'package:vikunja_mobile/core/db/account_database_files.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';

final _log = Logger('AccountDatabase');

/// Opens the account's database in a background isolate that other isolates
/// of this process share (`IsolateNameServer`, keyed by the account id).
/// The caller owns it: `close()` disconnects, and the isolate closes sqlite
/// once its last client is gone; [awaitAccountDatabaseClosed] waits for
/// that, which sign-out needs before it deletes the files.
AppDatabase openAccountDatabase({
  required String accountId,
  required AccountDatabaseFiles files,
  Future<String?> Function()? tempDirectoryPath,
}) => AppDatabase(
  driftDatabase(
    name: _databaseName(accountId),
    native: DriftNativeOptions(
      databasePath: () => files.pathFor(accountId),
      shareAcrossIsolates: true,
      setup: _enableWriteAheadLog,
      tempDirectoryPath: tempDirectoryPath,
    ),
  ),
);

/// Resolves once the database isolate has closed sqlite and unregistered
/// itself, or after [timeout], logged, when a client elsewhere keeps it
/// alive.
Future<void> awaitAccountDatabaseClosed(
  String accountId, {
  Duration timeout = const Duration(seconds: 5),
  Duration pollInterval = const Duration(milliseconds: 20),
}) async {
  final portName = accountDatabasePortName(accountId);
  final deadline = DateTime.now().add(timeout);
  while (IsolateNameServer.lookupPortByName(portName) != null) {
    if (!DateTime.now().isBefore(deadline)) {
      _log.warning(
        'The database isolate of account $accountId is still running after '
        '${timeout.inMilliseconds} ms',
      );
      return;
    }
    await Future<void>.delayed(pollInterval);
  }
}

/// Where drift_flutter registers the database isolate.
String accountDatabasePortName(String accountId) =>
    'drift-db/${_databaseName(accountId)}';

String _databaseName(String accountId) => 'account_$accountId';

// Sent to the database isolate, so it must be a top-level function.
void _enableWriteAheadLog(CommonDatabase database) {
  database.execute('PRAGMA journal_mode = WAL');
}
