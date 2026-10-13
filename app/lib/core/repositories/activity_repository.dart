import 'package:vikunja_domain/vikunja_domain.dart';

/// The active account's server notifications (the inbox), as this device
/// knows them; marking read applies at once and reaches the server with
/// the next activity sync.
abstract interface class ActivityRepository {
  /// Newest first.
  Stream<List<ServerNotification>> watchAll();

  /// The badge: the unread ones without the server's copies of reminders,
  /// which the phone has shown itself already.
  Stream<int> watchUnreadCount();

  /// Pulls the newest notifications and sends pending reads; with
  /// [wholeWindow] (pull-to-refresh) far enough back that the stored ones
  /// take the server's read state. Throws the `VikunjaFailure` and keeps
  /// the stored ones.
  Future<void> refresh({bool wholeWindow = false});

  /// Also takes the notification off the system's tray.
  Future<void> markRead(int notificationId);

  /// Also takes the notifications off the system's tray.
  Future<void> markAllRead();

  void dispose();
}
