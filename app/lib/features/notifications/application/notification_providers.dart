import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/notifications/application/notification_taps.dart';

part 'notification_providers.g.dart';

/// How many notifications the OS holds for [accountId]: the rows of its
/// `scheduled_notifications` table.
@riverpod
Stream<int> scheduledNotificationCount(Ref ref, String accountId) => ref
    .watch(appDatabaseProvider(accountId))
    .scheduledNotificationsDao
    .watchCount();

/// Taps on notifications: the plugin's responses while the app runs,
/// without the actions (those run in the background engine), and the
/// response that launched it.
@Riverpod(keepAlive: true)
NotificationTapSource notificationTapSource(Ref ref) {
  String? payloadOfTap(NotificationResponse? response) => switch (response) {
    NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotification,
      :final payload?,
    ) =>
      payload,
    _ => null,
  };
  final taps = NotificationTaps(
    launchPayload: () async =>
        payloadOfTap(await ref.read(notificationLaunchResponseProvider.future)),
  );
  final subscription = ref.watch(notificationResponsesProvider).stream.listen((
    response,
  ) {
    if (payloadOfTap(response) case final payload?) taps.add(payload);
  });
  ref.onDispose(() {
    unawaited(subscription.cancel());
    unawaited(taps.dispose());
  });
  return taps;
}
