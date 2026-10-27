import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/platform/recents_screenshots.dart';
import 'package:vikunja_mobile/core/platform/secure_display.dart';
import 'package:vikunja_mobile/core/security/app_lock_controller.dart';
import 'package:vikunja_mobile/core/security/privacy_providers.dart';

part 'screen_protection.g.dart';

final _log = Logger('ScreenProtection');

/// Keeps the window in step with the privacy settings: no Recents
/// thumbnail while the app lock is on (Android 13+), `FLAG_SECURE` while
/// Block screenshots is on. Bootstrap listens once the app runs.
@Riverpod(keepAlive: true)
void screenProtection(Ref ref) {
  final recents = ref.watch(recentsScreenshotsProvider);
  final display = ref.watch(secureDisplayProvider);
  ref
    ..listen(appLockControllerProvider.select((lock) => lock.enabled), (
      _,
      enabled,
    ) {
      unawaited(
        recents.setEnabled(!enabled).then<void>(
          (applied) {
            if (ref.mounted) {
              ref.read(recentsHiddenNativelyProvider.notifier).hidden = applied;
            }
          },
          onError: (Object error) =>
              _log.info('Recents thumbnail not changed: ${error.runtimeType}'),
        ),
      );
    }, fireImmediately: true)
    ..listen(privacySettingsProvider.select((settings) => settings.value), (
      _,
      settings,
    ) {
      if (settings != null) display.setAlways(settings.blockScreenshots);
    }, fireImmediately: true)
    ..onDispose(() => display.setAlways(false));
}
