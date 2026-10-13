import 'dart:async';

import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/background/background_scheduler.dart';
import 'package:vikunja_mobile/core/repositories/activity_repository.dart';

/// An inbox held in memory: [notifications] (newest first) is what the
/// streams replay; setting it, or marking read, emits again. The calls are
/// recorded; [refreshFailure] makes the next refreshes throw.
final class FakeActivityRepository implements ActivityRepository {
  new([List<ServerNotification> notifications = const []])
    : _notifications = List.of(notifications);

  List<ServerNotification> _notifications;
  final _changes = StreamController<void>.broadcast();

  final List<int> markedRead = [];
  int markAllReadCalls = 0;
  int refreshCalls = 0;
  bool disposed = false;

  /// Thrown by [refresh] while set, a `VikunjaFailure` as the real one
  /// throws.
  Exception? refreshFailure;

  /// Called by [refresh] before it returns; may change [notifications].
  Future<void> Function()? onRefresh;

  /// What the clock says when something is marked read here.
  DateTime Function() now = DateTime.now;

  List<ServerNotification> get notifications =>
      List.unmodifiable(_notifications);

  set notifications(List<ServerNotification> value) {
    _notifications = List.of(value);
    _emit();
  }

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  @override
  Stream<List<ServerNotification>> watchAll() =>
      _replaying(() => notifications);

  /// Like the real one, without the server's reminders.
  @override
  Stream<int> watchUnreadCount() => _replaying(
    () => _notifications
        .where((n) => !n.isRead && n.name != 'task.reminder')
        .length,
  ).distinct();

  int wholeWindowRefreshes = 0;

  @override
  Future<void> refresh({bool wholeWindow = false}) async {
    refreshCalls++;
    if (wholeWindow) wholeWindowRefreshes++;
    await onRefresh?.call();
    if (refreshFailure case final failure?) throw failure;
  }

  @override
  Future<void> markRead(int notificationId) async {
    markedRead.add(notificationId);
    _notifications = [
      for (final n in _notifications)
        if (n.id == notificationId && !n.isRead) _read(n) else n,
    ];
    _emit();
  }

  @override
  Future<void> markAllRead() async {
    markAllReadCalls++;
    _notifications = [
      for (final n in _notifications)
        if (n.isRead) n else _read(n),
    ];
    _emit();
  }

  @override
  void dispose() => disposed = true;

  ServerNotification _read(ServerNotification n) => ServerNotification(
    id: n.id,
    name: n.name,
    payload: n.payload,
    created: n.created,
    readAt: now(),
  );

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Stream<T> _replaying<T>(T Function() current) => Stream.multi((subscriber) {
    subscriber.add(current());
    final subscription = _changes.stream.listen(
      (_) => subscriber.add(current()),
    );
    subscriber.onCancel = subscription.cancel;
  });
}

/// Records what the app asked of the OS's background scheduler.
final class FakeBackgroundScheduler implements BackgroundScheduler {
  int registerCalls = 0;
  int drainCalls = 0;
  int cancelCalls = 0;

  /// `register`, `drain`, `cancel`, in order.
  final List<String> calls = [];

  /// Thrown by every call while set.
  Exception? failure;

  @override
  Future<void> registerPeriodicSync() async {
    calls.add('register');
    registerCalls++;
    if (failure case final failure?) throw failure;
  }

  @override
  Future<void> enqueueDrain() async {
    calls.add('drain');
    drainCalls++;
    if (failure case final failure?) throw failure;
  }

  @override
  Future<void> cancelAll() async {
    calls.add('cancel');
    cancelCalls++;
    if (failure case final failure?) throw failure;
  }
}
