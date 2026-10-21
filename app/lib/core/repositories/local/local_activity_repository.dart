import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/activity/activity_sync.dart';
import 'package:vikunja_mobile/core/activity/activity_tray.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/activity_repository.dart';

final _log = Logger('ActivityRepository');

/// The inbox of the account on screen, from its database. What a refresh
/// brings in counts as handled: the inbox shows it, so it never becomes an
/// OS notification as well. A read mark is stored at once, takes the
/// notification off the tray and is sent by a sync started right after it.
final class LocalActivityRepository implements ActivityRepository {
  new(
    this._db,
    this._sync, {
    required this._accountId,
    required this._tray,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final ActivitySync _sync;
  final String _accountId;
  final ActivityTray _tray;
  final DateTime Function() _now;
  var _disposed = false;

  @override
  Stream<List<ServerNotification>> watchAll() =>
      _db.serverNotificationsDao.watchAll();

  @override
  Future<ServerNotification?> find(int notificationId) =>
      _db.serverNotificationsDao.find(notificationId);

  @override
  Stream<int> watchUnreadCount() =>
      _db.serverNotificationsDao.watchUnreadCount().distinct();

  @override
  Future<void> refresh({bool wholeWindow = false}) async {
    final fresh = await _sync.run(wholeWindow: wholeWindow);
    if (fresh.isEmpty || _disposed) return;
    await _db.serverNotificationsDao.markHandled(fresh.map((n) => n.id));
  }

  @override
  Future<void> receive(ServerNotification notification) async {
    await _db.serverNotificationsDao.upsertAll([notification], handled: true);
  }

  @override
  Future<void> markRead(int notificationId) async {
    await _db.serverNotificationsDao.markRead([notificationId], at: _now());
    await _withdrawQuietly([notificationId]);
    _sendQuietly();
  }

  @override
  Future<void> markAllRead() async {
    final marked = await _db.serverNotificationsDao.markAllRead(at: _now());
    await _withdrawQuietly(marked);
    _sendQuietly();
  }

  Future<void> _withdrawQuietly(List<int> ids) async {
    if (ids.isEmpty) return;
    try {
      await _tray.withdraw(_accountId, ids);
    } on Object catch (error) {
      _log.info('Could not withdraw read notifications: ${error.runtimeType}');
    }
  }

  void _sendQuietly() {
    if (_disposed) return;
    unawaited(
      refresh().then<void>(
        (_) {},
        onError: (Object error) => _log.info(
          'Read marks stay queued for the next sync: ${error.runtimeType}',
        ),
      ),
    );
  }

  @override
  void dispose() => _disposed = true;
}
