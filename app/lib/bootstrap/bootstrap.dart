import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/theme/theme_providers.dart';
import 'package:vikunja_mobile/app/vikunja_app.dart';
import 'package:vikunja_mobile/bootstrap/logging_setup.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/background/background_entry_point.dart';
import 'package:vikunja_mobile/core/background/background_providers.dart';
import 'package:vikunja_mobile/core/legal/app_licenses.dart';
import 'package:vikunja_mobile/core/links/widget_link_key.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_entry_points.dart';
import 'package:vikunja_mobile/core/platform/backup_exclusion.dart';
import 'package:vikunja_mobile/core/security/app_lock_controller.dart';
import 'package:vikunja_mobile/core/security/privacy_providers.dart';
import 'package:vikunja_mobile/core/security/screen_protection.dart';
import 'package:vikunja_mobile/core/settings/user_settings_providers.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/features/notifications/application/notifications_onboarding.dart';
import 'package:workmanager/workmanager.dart';

final _log = Logger('Bootstrap');

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureLogging();
  registerAppLicenses();
  final clientIdentity = await ClientIdentity.load();
  final container = ProviderContainer(
    overrides: [
      clientIdentityProvider.overrideWithValue(clientIdentity),
      notificationBackgroundEntryPointProvider.overrideWithValue(
        onNotificationActionInBackground,
      ),
      deviceAppLocalizationsProvider.overrideWithValue(
        await loadDeviceAppLocalizations(SharedPreferencesStore()),
      ),
    ],
  );
  // Awaited even when the rest fails, so that the first frame is already
  // locked while the app lock is on.
  final privacy = container.read(privacySettingsControllerProvider.future);
  await _prepareWidgetLinkKey(container);
  try {
    // Behind the native launch screen, so the router starts on its first
    // real screen instead of animating it in over the empty splash route,
    // in the colours it keeps.
    final accounts = await container.read(accountsProvider.future);
    await Future.wait([
      _loadAppearance(container),
      if (accounts.activeAccount case final entry?) ...[
        // The shell, the first-sync screen or the notification setup:
        // decided by the stored sync state and the onboarding flag.
        firstSyncStatus(container, entry.id),
        container.read(notificationsOnboardingProvider.future),
      ],
    ]).timeout(const Duration(seconds: 5));
  } on Object catch (error) {
    _log.severe('Could not load the local state: ${error.runtimeType}');
  }
  try {
    await privacy.timeout(const Duration(seconds: 5));
  } on Object catch (error) {
    _log.severe('Could not read the privacy settings: ${error.runtimeType}');
  }
  container
    ..listen(foregroundHeartbeatProvider, (_, _) {})
    ..listen(appLockControllerProvider, (_, _) {});
  runApp(
    UncontrolledProviderScope(container: container, child: const VikunjaApp()),
  );
  container.listen(screenProtectionProvider, (_, _) {});
  unawaited(_initializeNotifications(container));
  unawaited(_initializeBackground(container));
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    unawaited(_excludeFromBackup());
  }
}

/// After the first frame, on iOS: the folders the app owns stay out of
/// backups (Android's extraction rules need no call). Never throws.
Future<void> _excludeFromBackup() async {
  await WidgetsBinding.instance.endOfFrame;
  await excludeAppDataFromBackup();
}

/// Before the registry's first read sets the install marker, which tells
/// a fresh install's new key from the one kept since.
Future<void> _prepareWidgetLinkKey(ProviderContainer container) async {
  try {
    await prepareWidgetLinkKey(container.read(preferencesStoreProvider))
        .timeout(const Duration(seconds: 5));
  } on Object catch (error) {
    _log.warning('Could not prepare the widget link key: ${error.runtimeType}');
  }
}

/// The account's colour scheme and the system colours, which the first
/// frame would otherwise switch away from a moment later. Never throws:
/// the app starts in the default colours instead.
Future<void> _loadAppearance(ProviderContainer container) async {
  // The app watches it from its first frame on; until then this keeps the
  // account's settings loaded.
  container.listen(themeModeProvider, (_, _) {});
  try {
    await Future.wait([
      container.read(userSettingsProvider.future),
      container.read(systemColorsProvider.future),
      container.read(useSystemColorsProvider.future),
    ]);
  } on Object catch (error) {
    _log.warning('Could not load the appearance: ${error.runtimeType}');
  }
}

/// After the first frame: hands the plugin the background entry point,
/// then keeps the periodic job registered while an account is signed in.
Future<void> _initializeBackground(ProviderContainer container) async {
  await WidgetsBinding.instance.endOfFrame;
  try {
    await Workmanager().initialize(callbackDispatcher);
  } on Object catch (error) {
    _log.warning(
      'Could not initialise the background scheduler: ${error.runtimeType}',
    );
    return;
  }
  container.listen(backgroundRegistrationProvider, (_, _) {});
}

/// Hands the plugin the tap callback and the background entry point before
/// a tap can arrive; the first frame does not wait for it, and the
/// gateway's other calls run it again if this failed.
Future<void> _initializeNotifications(ProviderContainer container) async {
  try {
    await container.read(notificationGatewayProvider).initialize();
  } on Object catch (error) {
    _log.warning(
      'Could not initialise the notification plugin: ${error.runtimeType}',
    );
  }
}
