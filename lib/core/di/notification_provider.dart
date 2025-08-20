import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/presentation/manager/notifications.dart';

part 'notification_provider.g.dart';

@Riverpod(keepAlive: true)
class Notification extends _$Notification {
  @override
  NotificationHandler? build() => null;

  void set(NotificationHandler notification) => state = notification;
}
