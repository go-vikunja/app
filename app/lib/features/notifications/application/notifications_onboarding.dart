import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';

part 'notifications_onboarding.g.dart';

const notificationsOnboardedKey = 'notifications.onboarded';

/// Whether the permission setup has been shown on this device. The router
/// sends a signed-in, synced account to it until [markDone].
@Riverpod(keepAlive: true)
class NotificationsOnboarding extends _$NotificationsOnboarding {
  @override
  Future<bool> build() async {
    final stored = await ref
        .watch(preferencesStoreProvider)
        .getString(notificationsOnboardedKey);
    return stored == 'true';
  }

  Future<void> markDone() async {
    await ref
        .read(preferencesStoreProvider)
        .setString(notificationsOnboardedKey, 'true');
    state = const AsyncData(true);
  }
}
