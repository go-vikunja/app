// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_notifications_dao.dart';

// ignore_for_file: type=lint
mixin _$ServerNotificationsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ServerNotificationsTable get serverNotifications =>
      attachedDatabase.serverNotifications;
  ServerNotificationsDaoManager get managers =>
      ServerNotificationsDaoManager(this);
}

class ServerNotificationsDaoManager {
  final _$ServerNotificationsDaoMixin _db;
  ServerNotificationsDaoManager(this._db);
  $$ServerNotificationsTableTableManager get serverNotifications =>
      $$ServerNotificationsTableTableManager(
        _db.attachedDatabase,
        _db.serverNotifications,
      );
}
