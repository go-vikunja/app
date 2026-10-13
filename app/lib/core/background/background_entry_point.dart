import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/bootstrap/logging_setup.dart';
import 'package:vikunja_mobile/core/background/background_run_log.dart';
import 'package:vikunja_mobile/core/background/background_sync_runner.dart';
import 'package:vikunja_mobile/core/background/workmanager_background_scheduler.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_entry_points.dart';
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
  DartPluginRegistrant.ensureInitialized();
  configureLogging();
  Workmanager().executeTask(
    (task, _) async {
      await runBackgroundTask(task);
      // Always a success: a failed run is retried by the next periodic one,
      // while `false` would make WorkManager back off exponentially (and
      // retry a one-off drain on its own schedule); iOS ignores the value.
      return true;
    },
    // Android tears the engine down as soon as this returns.
    onTaskStopped: (task, reason) async {
      _log.info('The system stopped the background task: ${reason.name}');
      await Future.wait([for (final run in List.of(_running)) run.stop()]);
    },
  );
}

final _log = Logger('BackgroundEntryPoint');

final _running = <BackgroundSyncRunner>{};

/// The drain task drains; everything else (the periodic sync, iOS's
/// background fetch) is the full run. The deadline stays under what the
/// OS grants: WorkManager stops a worker after 10 min, and iOS gives a
/// refresh task about 30 s; with the runner's grace for a token refresh
/// on its way it ends within either.
Future<BackgroundRunOutcome> runBackgroundTask(String task) async {
  final kind = task == BackgroundTasks.drain
      ? BackgroundRunKind.drain
      : BackgroundRunKind.sync;
  final runner = BackgroundSyncRunner(
    createContainer: createBackgroundContainer,
    deadline: switch ((kind, defaultTargetPlatform)) {
      (BackgroundRunKind.drain, _) => const Duration(minutes: 2),
      (_, TargetPlatform.iOS) => const Duration(seconds: 25),
      _ => const Duration(minutes: 9),
    },
  );
  _running.add(runner);
  try {
    return await runner.run(kind: kind);
  } finally {
    _running.remove(runner);
  }
}

/// A container like bootstrap's: the same client identity and texts, with
/// session managers that refresh.
Future<ProviderContainer> createBackgroundContainer() async =>
    ProviderContainer(
      overrides: [
        clientIdentityProvider.overrideWithValue(await ClientIdentity.load()),
        deviceAppLocalizationsProvider.overrideWithValue(
          await loadDeviceAppLocalizations(SharedPreferencesStore()),
        ),
        notificationBackgroundEntryPointProvider.overrideWithValue(
          onNotificationActionInBackground,
        ),
        runsHeadlessProvider.overrideWithValue(true),
      ],
    );
