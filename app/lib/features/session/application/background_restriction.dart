import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/platform/background_permissions.dart';

part 'background_restriction.g.dart';

/// What keeps the background sync from running, and with it the sessions
/// alive (D22, D40).
enum BackgroundRestriction {
  /// iOS: Background App Refresh is off, for the app or for every app.
  refreshOff,

  /// iOS: off by a restriction the user cannot lift in the app's settings,
  /// such as Screen Time's.
  refreshRestricted,

  /// Android: the user restricted the app's battery use, or the system put
  /// it in the restricted standby bucket.
  restricted;

  bool get hasSetting => this != refreshRestricted;
}

/// Null when nothing the OS reports keeps the background sync from
/// running; battery saving and Low Power Mode only pause it, also where iOS
/// reports Background App Refresh as denied while Low Power Mode is on.
BackgroundRestriction? backgroundRestrictionOf(BackgroundState state) =>
    switch (state) {
      BackgroundState(backgroundRefresh: 'denied', lowPowerMode: true) => null,
      BackgroundState(backgroundRefresh: 'denied') =>
        BackgroundRestriction.refreshOff,
      BackgroundState(backgroundRefresh: 'restricted') =>
        BackgroundRestriction.refreshRestricted,
      BackgroundState(backgroundRestricted: true) ||
      BackgroundState(
        standbyBucket: 'restricted',
      ) => BackgroundRestriction.restricted,
      _ => null,
    };

/// Read when first watched and again whenever the app comes back to the
/// front, because the user changes it in the system settings.
@riverpod
class BackgroundRestrictionState extends _$BackgroundRestrictionState {
  @override
  Future<BackgroundRestriction?> build() async {
    final lifecycle = AppLifecycleListener(onResume: _read);
    ref.onDispose(lifecycle.dispose);
    final permissions = ref.watch(backgroundPermissionsProvider);
    return backgroundRestrictionOf(await permissions.read());
  }

  Future<void> _read() async {
    final read = await ref.read(backgroundPermissionsProvider).read();
    if (!ref.mounted) return;
    state = AsyncData(backgroundRestrictionOf(read));
  }
}
