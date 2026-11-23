import 'dart:async';
import 'dart:ui' show IsolateNameServer;

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
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

/// Accounts signed out in this isolate whose database isolate was still
/// running when the sign-out gave up waiting. Per isolate, like the port
/// names they are looked up by: sign-out and sign-in both run in the app's.
final _signOutLeftovers = <String>{};

/// The settle under way per leftover: a user's sign-in waits for every
/// leftover and a guest's for its own, so two may meet on one account.
final _settling = <String, Future<void>>{};

/// Deletions of an account's local data under way in this isolate, which
/// close and delete the database a sign-in of the account would use.
final _dataDeletions = <String, Future<void>>{};

/// Until [deletion] completes, [settleSignedOutDatabases] holds off a
/// sign-in of [accountId]. Errors of [deletion] are its owner's.
void noteAccountDataDeletion(String accountId, Future<void> deletion) {
  late final Future<void> noted;
  noted = deletion.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
    if (identical(_dataDeletions[accountId], noted)) {
      unawaited(_dataDeletions.remove(accountId));
    }
  });
  _dataDeletions[accountId] = noted;
}

/// True once the database isolate has closed sqlite and unregistered
/// itself; false after [timeout], logged, when a client elsewhere keeps it
/// alive: the account is then remembered as a leftover for
/// [settleSignedOutDatabases].
Future<bool> awaitAccountDatabaseClosed(
  String accountId, {
  Duration timeout = const Duration(seconds: 5),
  Duration pollInterval = const Duration(milliseconds: 20),
}) async {
  final closed = await _awaitIsolateGone(
    accountId,
    deadline: DateTime.now().add(timeout),
    pollInterval: pollInterval,
  );
  if (!closed) {
    _log.warning(
      'The database isolate of account $accountId is still running after '
      '${timeout.inMilliseconds} ms',
    );
    _signOutLeftovers.add(accountId);
  }
  return closed;
}

/// Whether a sign-in has to settle a sign-out first.
bool get hasSignOutLeftovers => _signOutLeftovers.isNotEmpty;

/// A sign-in must not register an account again while its data is still
/// being deleted ([noteAccountDataDeletion]), nor while the database
/// isolate of its sign-out still runs: the new database would attach to
/// it, by its port name, and work on the deleted files. Waits for every
/// deletion (or only [accountId]'s), then until the isolate of every
/// leftover (or only [accountId]'s) has gone, deletes its files once more,
/// and forgets it; throws [SignOutStillFinishing] when one is still running
/// after [timeout]. Returns at once without either.
Future<void> settleSignedOutDatabases(
  AccountDatabaseFiles files, {
  String? accountId,
  Duration timeout = const Duration(seconds: 30),
  Duration pollInterval = const Duration(milliseconds: 100),
}) async {
  final deadline = DateTime.now().add(timeout);
  await _awaitDataDeletions(accountId, deadline: deadline, timeout: timeout);
  // Read only now: a deletion that gave up waiting for its database left
  // one.
  final leftovers = [
    for (final id in _signOutLeftovers)
      if (accountId == null || id == accountId) id,
  ];
  if (leftovers.isEmpty) return;
  for (final id in leftovers) {
    // Settled by another sign-in meanwhile, and maybe registered again:
    // its database is a new one now.
    if (!_signOutLeftovers.contains(id)) continue;
    // Once done, the settle forgets itself, without waiting for what the
    // removal returns: that is this very future.
    await (_settling[id] ??= _settleLeftover(
      files,
      id,
      deadline: deadline,
      timeout: timeout,
      pollInterval: pollInterval,
    ).whenComplete(() => unawaited(_settling.remove(id))));
  }
}

Future<void> _awaitDataDeletions(
  String? accountId, {
  required DateTime deadline,
  required Duration timeout,
}) async {
  while (true) {
    final running = {
      for (final MapEntry(key: id, value: deletion) in _dataDeletions.entries)
        if (accountId == null || id == accountId) id: deletion,
    };
    if (running.isEmpty) return;
    final ids = running.keys.join(', ');
    _log.info('Waiting for the local data of account $ids to be deleted');
    try {
      await Future.wait(running.values)
          .timeout(deadline.difference(DateTime.now()));
    } on TimeoutException {
      _log.warning(
        'The local data of account $ids is still being deleted after '
        '${timeout.inSeconds} s',
      );
      throw const SignOutStillFinishing();
    }
  }
}

Future<void> _settleLeftover(
  AccountDatabaseFiles files,
  String accountId, {
  required DateTime deadline,
  required Duration timeout,
  required Duration pollInterval,
}) async {
  _log.info('Waiting for the database of account $accountId from its sign-out');
  final closed = await _awaitIsolateGone(
    accountId,
    deadline: deadline,
    pollInterval: pollInterval,
  );
  if (!closed) {
    _log.warning(
      'The database of account $accountId from its sign-out is still open '
      'after ${timeout.inSeconds} s',
    );
    throw const SignOutStillFinishing();
  }
  await files.deleteFor(accountId);
  _signOutLeftovers.remove(accountId);
  _log.info('The database of account $accountId from its sign-out has closed');
}

/// Part of the app still holds the database of an account just signed
/// out, so it cannot be signed in again yet.
final class SignOutStillFinishing implements Exception {
  const new();

  @override
  String toString() => 'SignOutStillFinishing';
}

@visibleForTesting
void forgetSignOutLeftovers() {
  _signOutLeftovers.clear();
  _settling.clear();
  _dataDeletions.clear();
}

Future<bool> _awaitIsolateGone(
  String accountId, {
  required DateTime deadline,
  required Duration pollInterval,
}) async {
  final portName = accountDatabasePortName(accountId);
  while (IsolateNameServer.lookupPortByName(portName) != null) {
    if (!DateTime.now().isBefore(deadline)) return false;
    await Future<void>.delayed(pollInterval);
  }
  return true;
}

/// Where drift_flutter registers the database isolate.
String accountDatabasePortName(String accountId) =>
    'drift-db/${_databaseName(accountId)}';

String _databaseName(String accountId) => 'account_$accountId';

// Sent to the database isolate, so it must be a top-level function.
void _enableWriteAheadLog(CommonDatabase database) {
  database.execute('PRAGMA journal_mode = WAL');
}
