import 'dart:async';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';

final _log = Logger('ActivitySync');

/// Mirrors one account's server notifications into its database and sends
/// the read marks made here. Headless: the ports, the database and a clock
/// are injected. Runs are serialized; a call during a run joins it.
final class ActivitySync {
  new({
    required this._db,
    required this._read,
    required this._write,
    DateTime Function()? now,
    this._withdraw,
    this.perPage = 50,
    this.maxPages = 3,
    this.keep = 200,
    this.windowCheckInterval = const Duration(hours: 1),
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final NotificationsPort _read;
  final NotificationsWritePort _write;
  final DateTime Function() _now;

  /// Takes the notifications the server has read now off the device.
  final Future<void> Function(List<int> notificationIds)? _withdraw;
  final int perPage;

  /// A run reads no further back than this, so an account that collected
  /// hundreds of notifications on the web costs a few requests at most.
  final int maxPages;
  final int keep;

  /// How often a run reads back past the first stored notification, so
  /// that what was read on the web or another device is read here too.
  final Duration windowCheckInterval;
  Future<List<ServerNotification>>? _running;

  /// Pulls the newest pages until one holds a stored notification (or
  /// [maxPages]), stores them, sends the pending read marks and returns the
  /// unread notifications that were never handled, oldest first. The very
  /// first run of an account stores everything as handled and returns
  /// nothing, so the history does not arrive as a flood of notifications.
  ///
  /// With [wholeWindow] (pull-to-refresh), and otherwise once per
  /// [windowCheckInterval], the pull goes on past the stored ones while an
  /// older stored one is unread here, up to the [keep] stored ones, so
  /// their read state follows the server's. What the server has read now
  /// is withdrawn from the tray.
  ///
  /// The pull comes first, so a "mark all read" is only sent as one
  /// request when nothing unread arrived since the user saw the list.
  /// Throws the `VikunjaFailure` of the pull; a failed mark stays pending.
  Future<List<ServerNotification>> run({bool wholeWindow = false}) =>
      _running ??= _run(wholeWindow: wholeWindow)
          .whenComplete(() => _running = null);

  Future<List<ServerNotification>> _run({required bool wholeWindow}) async {
    final dao = _db.serverNotificationsDao;
    final state = await _db.syncStateDao.readAll();
    final firstRun = state[SyncStateKeys.activitySyncedAt] == null;
    final checkedAt = DateTime.tryParse(
      state[SyncStateKeys.activityWindowCheckedAt] ?? '',
    );
    final checkWindow =
        wholeWindow ||
        checkedAt == null ||
        _now().toUtc().difference(checkedAt) >= windowCheckInterval;
    final pageLimit = checkWindow
        ? max(maxPages, (keep / perPage).ceil())
        : maxPages;
    final pulled = <ServerNotification>[];
    // Pages past the first stored one: whatever they hold that is not
    // stored is older than what was ever shown, never new.
    final older = <ServerNotification>[];
    var pastStored = false;
    for (var page = 1; page <= pageLimit; page++) {
      final result = await _read.list(page: page, perPage: perPage);
      (pastStored ? older : pulled).addAll(result.items);
      if (!result.hasMore || result.items.isEmpty) break;
      if (!pastStored) {
        final known = await dao.existingIds(result.items.map((n) => n.id));
        if (known.isEmpty) {
          if (page >= maxPages) break;
          continue;
        }
        if (!checkWindow) break;
        pastStored = true;
      }
      final lowest = result.items.map((n) => n.id).reduce(min);
      if (!await dao.hasUnreadBelow(lowest)) break;
    }
    final readOnServer = [
      ...await dao.upsertAll(pulled, handled: firstRun),
      ...await dao.upsertAll(older, handled: true),
    ];
    await _sendPendingReads();
    await dao.pruneToNewest(keep);
    final now = _now().toUtc().toIso8601String();
    await _db.syncStateDao.write({
      SyncStateKeys.activitySyncedAt: now,
      if (checkWindow) SyncStateKeys.activityWindowCheckedAt: now,
    });
    if (readOnServer.isNotEmpty) await _withdrawQuietly(readOnServer);
    _log.fine(
      'Activity: ${pulled.length + older.length} pulled, first run '
      '$firstRun, ${readOnServer.length} read elsewhere',
    );
    if (firstRun) return const [];
    return await dao.unhandledUnread();
  }

  Future<void> _withdrawQuietly(List<int> ids) async {
    try {
      await _withdraw?.call(ids);
    } on Object catch (error) {
      _log.info('Could not withdraw read notifications: ${error.runtimeType}');
    }
  }

  /// "Mark all read" goes out as one request when every unread
  /// notification is marked; anything else mark by mark, stopping at the
  /// first failure that a later run may get past.
  Future<void> _sendPendingReads() async {
    final dao = _db.serverNotificationsDao;
    final pending = await dao.pendingReads();
    if (pending.isEmpty) return;
    final allRead = pending.every((mark) => mark.read);
    if (allRead && pending.length > 1 && await dao.unreadCount() == 0) {
      try {
        await _write.markAllRead();
        await dao.clearPending(pending.map((mark) => mark.id));
      } on VikunjaFailure catch (failure) {
        _log.info('Mark all read failed: ${failure.runtimeType}');
        if (!_isTransient(failure)) {
          await dao.clearPending(pending.map((mark) => mark.id));
        }
      }
      return;
    }
    for (final mark in pending) {
      try {
        await _write.markRead(mark.id, read: mark.read);
      } on VikunjaFailure catch (failure) {
        _log.info('Read mark of ${mark.id} failed: ${failure.runtimeType}');
        if (_isTransient(failure)) return;
      }
      // A mark the server refused for good is dropped; the next pull shows
      // what the server has.
      await dao.clearPending([mark.id]);
    }
  }

  static bool _isTransient(VikunjaFailure failure) => switch (failure) {
    NetworkFailure() ||
    ServerFailure() ||
    RateLimited() ||
    RefreshRaceLost() ||
    TokenRejected() ||
    SessionEnded() => true,
    NotFound(:final routeAbsent) => routeAbsent,
    UnexpectedResponse(:final statusCode) =>
      statusCode == null || statusCode < 400,
    _ => false,
  };
}
