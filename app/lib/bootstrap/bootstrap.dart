import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/vikunja_app.dart';
import 'package:vikunja_mobile/bootstrap/logging_setup.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/background/background_entry_point.dart';
import 'package:vikunja_mobile/core/background/background_providers.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_entry_points.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/features/notifications/application/notifications_onboarding.dart';
import 'package:workmanager/workmanager.dart';

final _log = Logger('Bootstrap');

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureLogging();
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
  try {
    // Behind the native launch screen, so the router starts on its first
    // real screen instead of animating it in over the empty splash route.
    final accounts = await container.read(accountsProvider.future);
    if (accounts.activeAccount case final entry?) {
      // The shell, the first-sync screen or the notification setup: decided
      // by the stored sync state and the onboarding flag.
      await Future.wait([
        firstSyncStatus(container, entry.id),
        container.read(notificationsOnboardingProvider.future),
      ]).timeout(const Duration(seconds: 5));
    }
  } on Object catch (error) {
    _log.severe('Could not load the local state: ${error.runtimeType}');
  }
  container.listen(foregroundHeartbeatProvider, (_, _) {});
  runApp(
    UncontrolledProviderScope(container: container, child: const VikunjaApp()),
  );
  unawaited(_initializeNotifications(container));
  unawaited(_initializeBackground(container));
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
