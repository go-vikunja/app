import 'package:flutter/foundation.dart';
import 'package:vikunja_mobile/core/background/background_scheduler.dart';
import 'package:workmanager/workmanager.dart';

/// The task names the OS hands back to the callback dispatcher. The sync's
/// name doubles as the iOS BGTaskScheduler identifier, so it must equal
/// `BGTaskSchedulerPermittedIdentifiers` in `ios/Runner/Info.plist` and the
/// identifier `AppDelegate.swift` registers.
abstract final class BackgroundTasks {
  static const sync = 'dev.coderoftime.rurana.sync';
  static const drain = 'dev.coderoftime.rurana.drain';
}

/// The calls of the `workmanager` plugin this app makes, so the adapter can
/// be tested without the platform.
abstract interface class WorkmanagerClient {
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingPeriodicWorkPolicy? existingWorkPolicy,
  });

  Future<void> registerOneOffTask(
    String uniqueName,
    String taskName, {
    Constraints? constraints,
    ExistingWorkPolicy? existingWorkPolicy,
    OutOfQuotaPolicy? outOfQuotaPolicy,
    bool expedited,
  });

  Future<void> cancelAll();
}

final class PluginWorkmanagerClient implements WorkmanagerClient {
  const new();

  @override
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingPeriodicWorkPolicy? existingWorkPolicy,
  }) => Workmanager().registerPeriodicTask(
    uniqueName,
    taskName,
    frequency: frequency,
    initialDelay: initialDelay,
    constraints: constraints,
    existingWorkPolicy: existingWorkPolicy,
  );

  @override
  Future<void> registerOneOffTask(
    String uniqueName,
    String taskName, {
    Constraints? constraints,
    ExistingWorkPolicy? existingWorkPolicy,
    OutOfQuotaPolicy? outOfQuotaPolicy,
    bool expedited = false,
  }) => Workmanager().registerOneOffTask(
    uniqueName,
    taskName,
    constraints: constraints,
    existingWorkPolicy: existingWorkPolicy,
    outOfQuotaPolicy: outOfQuotaPolicy,
    expedited: expedited,
  );

  @override
  Future<void> cancelAll() => Workmanager().cancelAll();
}

/// [BackgroundScheduler] over WorkManager (Android) and BGTaskScheduler
/// (iOS). One periodic job syncs every account.
final class WorkmanagerBackgroundScheduler implements BackgroundScheduler {
  new({
    this._client = const PluginWorkmanagerClient(),
    TargetPlatform? platform,
  }) : _platform = platform ?? defaultTargetPlatform;

  static const syncInterval = Duration(minutes: 30);

  final WorkmanagerClient _client;
  final TargetPlatform _platform;

  bool get _iOS => _platform == TargetPlatform.iOS;

  /// Android: every 30 min when a network is there, the same job updated
  /// rather than duplicated or restarted. iOS ignores the frequency: the
  /// initial delay becomes the request's `earliestBeginDate`, and every run
  /// submits the next request with the same delay; when it runs is the
  /// system's choice.
  @override
  Future<void> registerPeriodicSync() => _client.registerPeriodicTask(
    BackgroundTasks.sync,
    BackgroundTasks.sync,
    frequency: syncInterval,
    initialDelay: _iOS ? syncInterval : null,
    constraints: _iOS ? null : Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );

  /// Android only: an ordinary one-off job with a network, which usually
  /// runs within minutes. Not expedited: below Android 12 WorkManager runs
  /// expedited work as a foreground service, which the plugin's worker
  /// cannot provide, and fails it before it starts. A drain asked for while
  /// one runs is chained after it (natively `APPEND_OR_REPLACE`), as the
  /// running one may have looked at the queue before this op was due. iOS
  /// has no on-demand background run, so the op waits for the next
  /// periodic run or the app.
  @override
  Future<void> enqueueDrain() async {
    if (_iOS) return;
    await _client.registerOneOffTask(
      BackgroundTasks.drain,
      BackgroundTasks.drain,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.append,
    );
  }

  @override
  Future<void> cancelAll() => _client.cancelAll();
}
