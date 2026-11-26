import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/vikunja_app.dart';
import 'package:vikunja_mobile/app/widgets/release_error_widget.dart';
import 'package:vikunja_mobile/bootstrap/appearance_start.dart';
import 'package:vikunja_mobile/bootstrap/previous_app_start.dart';
import 'package:vikunja_mobile/bootstrap/start_values.dart';
import 'package:vikunja_mobile/core/attachments/attachment_image_providers.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/background/background_entry_point.dart';
import 'package:vikunja_mobile/core/background/background_providers.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_providers.dart';
import 'package:vikunja_mobile/core/legal/app_licenses.dart';
import 'package:vikunja_mobile/core/links/deep_link_providers.dart';
import 'package:vikunja_mobile/core/links/deep_link_relay.dart';
import 'package:vikunja_mobile/core/links/widget_link_key.dart';
import 'package:vikunja_mobile/core/logging/logging_setup.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_entry_points.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
import 'package:vikunja_mobile/core/platform/backup_exclusion.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_import.dart';
import 'package:vikunja_mobile/core/security/app_lock_controller.dart';
import 'package:vikunja_mobile/core/security/privacy_providers.dart';
import 'package:vikunja_mobile/core/security/screen_protection.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/features/notifications/application/notifications_onboarding.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_providers.dart';
import 'package:workmanager/workmanager.dart';

final _log = Logger('Bootstrap');

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final earlyRoutes = EarlyPushedRoutes();
  configureLogging(part: AppPart.app);
  installErrorWidget();
  registerAppLicenses();
  final (:clientIdentity, :deviceL10n) = await loadStartValues();
  final container = createAppContainer(
    overrides: [
      clientIdentityProvider.overrideWithValue(clientIdentity),
      notificationBackgroundEntryPointProvider.overrideWithValue(
        onNotificationActionInBackground,
      ),
      deviceAppLocalizationsProvider.overrideWithBuild((_, _) => deviceL10n),
    ],
    earlyRoutes: earlyRoutes,
  );
  await prepareFirstFrame(container);
  runApp(
    UncontrolledProviderScope(container: container, child: const VikunjaApp()),
  );
  container
    ..listen(screenProtectionProvider, (_, _) {})
    ..listen(inactiveAttachmentImagesProvider, (_, _) {});
  unawaited(_initializeNotifications(container));
  unawaited(_initializeBackground(container));
  unawaited(_finishSignOuts(container));
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    unawaited(_excludeFromBackup());
  }
}

/// Never throws: the app runs even when the account list cannot be read.
Future<void> prepareFirstFrame(ProviderContainer container) async {
  // Awaited even when the rest fails, so that the first frame is already
  // locked while the app lock is on.
  final privacy = container.read(privacySettingsControllerProvider.future);
  await _prepareWidgetLinkKey(container);
  final previousApp = await importPreviousApp(container);
  // From here on the app's errors wait for the crash report choice, which
  // sends or drops them once it is read (decision log: Diagnostics). Not before
  // the import: the reporter reads the registry, whose first read wipes what it
  // reads.
  container.listen(crashReporterProvider, (_, _) {});
  // Behind the native launch screen, so the router starts on its first
  // real screen in the colours it keeps. A timed-out wait must not cancel
  // migration: keep listening for the registry, including after a retry.
  try {
    final accountsRead = container.read(accountsProvider.future);
    final migration = _migrateAfterAccountRead(container, previousApp);
    final accounts = await accountsRead.timeout(startupReadLimit);
    await Future.wait([
      loadAppearance(container),
      migration,
      if (accounts.activeAccount case final entry?) ...[
        firstSyncStatus(container, entry.id),
        container.read(notificationsOnboardingProvider.future),
      ],
    ]).timeout(startupReadLimit);
  } on Object catch (error) {
    _log.severe('Could not load the local state: ${error.runtimeType}');
  }
  try {
    await privacy.timeout(const Duration(seconds: 5));
  } on Object catch (error) {
    _log.severe('Could not read the privacy settings: ${error.runtimeType}');
  }
  container
    ..listen(deviceLanguageFollowerProvider, (_, _) {})
    ..listen(foregroundHeartbeatProvider, (_, _) {})
    ..listen(appLockControllerProvider, (_, _) {});
}

Future<void> _migrateAfterAccountRead(
  ProviderContainer container,
  PreviousAppFindings? previousApp,
) async {
  // Without findings, only the stored record is loaded, which Connect
  // fills its address from.
  if (previousApp == null) {
    await startPreviousApp(container, null);
    return;
  }
  final ready = Completer<void>();
  final subscription = container.listen(accountsProvider, (_, next) {
    if (next is AsyncData<AccountRegistryState> && !ready.isCompleted) {
      ready.complete();
    }
  }, fireImmediately: true);
  try {
    await ready.future;
  } finally {
    subscription.close();
  }
  await startPreviousApp(container, previousApp);
}

ProviderContainer createAppContainer({
  required List<Override> overrides,
  EarlyPushedRoutes? earlyRoutes,
}) {
  // First among the binding's observers once [earlyRoutes] leaves: the
  // binding offers a pushed route to each in turn until one takes it, and
  // the others (every AppLifecycleListener, runApp's View) read its query,
  // which throws on an escape that is no UTF-8 and gets reported.
  final container = ProviderContainer(overrides: overrides)
    ..listen(appSchemeLinksProvider, (_, _) {});
  earlyRoutes?._handTo(container.read(deepLinkRelayProvider));
  return container;
}

/// Holds the routes the platform pushes before the app's container exists,
/// which the binding would drop with no observer to take them, for
/// [createAppContainer] to hand on.
final class EarlyPushedRoutes with WidgetsBindingObserver {
  new() {
    WidgetsBinding.instance.addObserver(this);
  }

  final _uris = <Uri>[];

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) {
    _uris.add(routeInformation.uri);
    return SynchronousFuture(true);
  }

  void _handTo(DeepLinkRelay relay) {
    WidgetsBinding.instance.removeObserver(this);
    _uris
      ..forEach(relay.accept)
      ..clear();
  }
}

/// After the first frame, on iOS: the folders the app owns stay out of
/// backups (Android's extraction rules need no call). Never throws.
Future<void> _excludeFromBackup() async {
  await WidgetsBinding.instance.endOfFrame;
  await excludeAppDataFromBackup();
}

/// After the first frame: deletes the data of accounts whose sign-out a
/// crash or a failed wipe left unfinished. Never throws.
Future<void> _finishSignOuts(ProviderContainer container) async {
  await WidgetsBinding.instance.endOfFrame;
  await container.read(accountDeletionsProvider).finishAll();
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
