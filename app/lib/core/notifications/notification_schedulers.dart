import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/notifications/notification_scheduler.dart';

part 'notification_schedulers.g.dart';

/// The schedulers this isolate has built, one per account. An account's
/// scheduler stays registered after its provider disposed it, until
/// sign-out has cancelled the account's notifications: by the time the
/// wipe runs, the registry change has already rebuilt the providers and
/// closed the database, and the scheduler still knows the ids it held.
final class NotificationSchedulers {
  final _schedulers = <String, NotificationScheduler>{};

  NotificationScheduler? find(String accountId) => _schedulers[accountId];

  /// Replaces the account's earlier scheduler, which is disposed.
  void register(NotificationScheduler scheduler) {
    final previous = _schedulers[scheduler.accountId];
    if (previous != null && !identical(previous, scheduler)) {
      unawaited(previous.dispose());
    }
    _schedulers[scheduler.accountId] = scheduler;
  }

  /// The permission was granted or refused inside the app, which no
  /// scheduler trigger sees: every account looks again. Errors are logged.
  void reconcileAll() {
    for (final scheduler in _schedulers.values) {
      scheduler.reconcileQuietly();
    }
  }

  /// Sign-out: cancels what the account holds and forgets its scheduler.
  Future<void> cancelAll(String accountId) async {
    final scheduler = _schedulers.remove(accountId);
    if (scheduler == null) return;
    try {
      await scheduler.cancelAll();
    } finally {
      await scheduler.dispose();
    }
  }
}

@Riverpod(keepAlive: true)
NotificationSchedulers notificationSchedulers(Ref ref) =>
    NotificationSchedulers();
