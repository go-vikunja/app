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

  /// Replaces the account's earlier scheduler, which is disposed. True
  /// when the account had none (its first in this isolate, or the first
  /// after its sign-out) or the earlier one was disposed before its re-arm
  /// reached the OS.
  bool register(NotificationScheduler scheduler) {
    final previous = _schedulers[scheduler.accountId];
    if (previous != null && !identical(previous, scheduler)) {
      unawaited(previous.dispose());
    }
    _schedulers[scheduler.accountId] = scheduler;
    return previous == null || previous.rearmPending;
  }

  /// The permission was granted or refused inside the app, which no
  /// scheduler trigger sees: every account looks again. Errors are logged.
  void reconcileAll() {
    for (final scheduler in _schedulers.values) {
      scheduler.reconcileQuietly();
    }
  }

  /// Sign-out: forgets the account's scheduler, lets a run under way stop,
  /// then cancels what the account holds, so nothing is planned after it.
  Future<void> cancelAll(String accountId) async {
    final scheduler = _schedulers.remove(accountId);
    if (scheduler == null) return;
    await scheduler.dispose();
    await scheduler.idle;
    await scheduler.cancelAll();
  }
}

@Riverpod(keepAlive: true)
NotificationSchedulers notificationSchedulers(Ref ref) =>
    NotificationSchedulers();
