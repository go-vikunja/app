// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduled_notifications_dao.dart';

// ignore_for_file: type=lint
mixin _$ScheduledNotificationsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ScheduledNotificationsTable get scheduledNotifications =>
      attachedDatabase.scheduledNotifications;
  ScheduledNotificationsDaoManager get managers =>
      ScheduledNotificationsDaoManager(this);
}

class ScheduledNotificationsDaoManager {
  final _$ScheduledNotificationsDaoMixin _db;
  ScheduledNotificationsDaoManager(this._db);
  $$ScheduledNotificationsTableTableManager get scheduledNotifications =>
      $$ScheduledNotificationsTableTableManager(
        _db.attachedDatabase,
        _db.scheduledNotifications,
      );
}
