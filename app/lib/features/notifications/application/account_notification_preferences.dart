import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';

part 'account_notification_preferences.g.dart';

/// One account's switches: the stored value, then every write.
@riverpod
Stream<NotificationPreferences> accountNotificationPreferences(
  Ref ref,
  String accountId,
) {
  final store = ref.watch(notificationPreferencesStoreProvider);
  final controller = StreamController<NotificationPreferences>();
  final subscription = store.changes.listen((change) {
    final (changedAccountId, preferences) = change;
    if (changedAccountId == accountId) controller.add(preferences);
  });
  unawaited(
    store.read(accountId).then(controller.add, onError: controller.addError),
  );
  ref.onDispose(() {
    unawaited(subscription.cancel());
    unawaited(controller.close());
  });
  return controller.stream;
}
