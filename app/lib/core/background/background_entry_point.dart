import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/bootstrap/logging_setup.dart';
import 'package:vikunja_mobile/core/auth/auth_gateways.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/background/background_run_log.dart';
import 'package:vikunja_mobile/core/background/background_sync_runner.dart';
import 'package:vikunja_mobile/core/background/workmanager_background_scheduler.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_entry_points.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:workmanager/workmanager.dart';

/// What WorkManager (Android) and BGTaskScheduler (iOS) run, in an engine
/// of their own or, for a one-off task while the app runs, in the app's:
/// handed to `Workmanager().initialize` in bootstrap. The pragma keeps it
/// from being tree-shaken, as the native side looks it up by its callback
/// handle.
@pragma('vm:entry-point')
void callbackDispatcher() {
  // Before the diagnostics log asks the platform for its folder;
  // executeTask would bind it only later.
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  configureLogging(part: AppPart.backgroundRun);
  Workmanager().executeTask(
    (task, _) async {
      await runBackgroundTask(task);
      // Always a success: a failed run is retried by the next periodic one,
      // while `false` would make WorkManager back off exponentially (and
      // retry a one-off drain on its own schedule); iOS ignores the value.
      return true;
    },
    // Android tears the engine down as soon as this returns. The plugin
    // passes Android's raw `WorkInfo` number, which `StopReason`'s names do
    // not match, so only `rawValue` means anything (0 from 10 on).
    onTaskStopped: (task, reason) async {
      _log.info('The system stopped the background task: ${reason.rawValue}');
      await Future.wait([
        for (final run in List.of(_running)) run.stop(reason: reason.rawValue),
      ]);
    },
  );
}

final _log = Logger('BackgroundEntryPoint');

final _running = <BackgroundSyncRunner>{};

/// The drain task drains; everything else (the periodic sync, iOS's
/// background fetch) is the full run. The deadline stays under what the
/// OS grants: WorkManager stops a worker after 10 min, and iOS gives a
/// refresh task about 30 s.
Future<BackgroundRunOutcome> runBackgroundTask(String task) async {
  final kind = task == BackgroundTasks.drain
      ? BackgroundRunKind.drain
      : BackgroundRunKind.sync;
  final deadline = switch ((kind, defaultTargetPlatform)) {
    (BackgroundRunKind.drain, _) => const Duration(minutes: 2),
    (_, TargetPlatform.iOS) => const Duration(seconds: 25),
    _ => const Duration(minutes: 9),
  };
  final runner = BackgroundSyncRunner(
    createContainer: createBackgroundContainer,
    deadline: deadline,
  );
  _running.add(runner);
  try {
    return await runner.run(kind: kind);
  } finally {
    _running.remove(runner);
  }
}

/// The connect timeout of a token request in a background run, which the
/// native adapters add to its receive timeout: short on iOS, whose runs
/// last about 30 s.
Duration get backgroundConnectTimeout =>
    defaultTargetPlatform == TargetPlatform.iOS
    ? const Duration(seconds: 5)
    : const Duration(seconds: 10);

/// The least time a token refresh in a background run gets for its answer;
/// with less left before the run's container goes, none starts (D59).
Duration get backgroundTokenTimeout =>
    defaultTargetPlatform == TargetPlatform.iOS
    ? const Duration(seconds: 8)
    : const Duration(seconds: 30);

/// A container like bootstrap's: the same client identity and texts, with
/// session managers that refresh while the run's [RefreshCutoff] allows,
/// each token request bounded by the time it leaves.
Future<ProviderContainer> createBackgroundContainer() async =>
    ProviderContainer(
      overrides: [
        ...backgroundTokenOverrides,
        clientIdentityProvider.overrideWithValue(await ClientIdentity.load()),
        deviceAppLocalizationsProvider.overrideWithValue(
          await loadDeviceAppLocalizations(SharedPreferencesStore()),
        ),
        notificationBackgroundEntryPointProvider.overrideWithValue(
          onNotificationActionInBackground,
        ),
        ...backgroundRunOverrides,
      ],
    );

final List<Override> backgroundTokenOverrides = [
  refreshCutoffProvider.overrideWith(
    (ref) => RefreshCutoff(
      connectTimeout: backgroundConnectTimeout,
      minimumTokenTimeout: backgroundTokenTimeout,
    ),
  ),
  authDioProvider.overrideWith(
    (ref) => createAuthDio(ref, connectTimeout: backgroundConnectTimeout),
  ),
  tokenGatewayProvider.overrideWith((ref) {
    final cutoff = ref.watch(refreshCutoffProvider);
    return ApiTokenGateway(
      ref.watch(authDioProvider),
      timeout: () => cutoff.tokenTimeout,
    );
  }),
];

final List<Override> backgroundRunOverrides = [
  runsHeadlessProvider.overrideWithValue(true),
  appPartProvider.overrideWithValue(AppPart.backgroundRun),
];
