import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/background/background_run_log.dart';
import 'package:vikunja_mobile/core/background/background_scheduler.dart';
import 'package:vikunja_mobile/core/background/foreground_heartbeat.dart';
import 'package:vikunja_mobile/core/background/workmanager_background_scheduler.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

part 'background_providers.g.dart';

final _log = Logger('BackgroundScheduler');

@Riverpod(keepAlive: true)
BackgroundScheduler backgroundScheduler(Ref ref) =>
    WorkmanagerBackgroundScheduler();

@Riverpod(keepAlive: true)
BackgroundRunLog backgroundRunLog(Ref ref) =>
    BackgroundRunLog(ref.watch(preferencesStoreProvider));

/// Beats while the app is visible: from now when it is, and from every
/// show or resume until it is hidden. Bootstrap listens.
@Riverpod(keepAlive: true)
ForegroundHeartbeat foregroundHeartbeat(Ref ref) {
  final heartbeat = ForegroundHeartbeat(
    runLog: ref.watch(backgroundRunLogProvider),
    now: ref.watch(clockProvider),
  );
  final lifecycle = AppLifecycleListener(
    onShow: heartbeat.resume,
    onResume: heartbeat.resume,
    onHide: heartbeat.pause,
  );
  ref.onDispose(() {
    lifecycle.dispose();
    heartbeat.pause();
  });
  switch (WidgetsBinding.instance.lifecycleState) {
    case null || AppLifecycleState.resumed || AppLifecycleState.inactive:
      heartbeat.resume();
    case _:
      break;
  }
  return heartbeat;
}

/// Keeps the OS's periodic job in step with the accounts: registered while
/// at least one account is signed in (again on every app start, which
/// updates rather than duplicates it), cancelled after the last sign-out.
/// Bootstrap listens once `Workmanager` is initialised.
@Riverpod(keepAlive: true)
void backgroundRegistration(Ref ref) {
  final scheduler = ref.watch(backgroundSchedulerProvider);
  ref.listen(
    accountsProvider.select((accounts) => accounts.value?.accounts.isNotEmpty),
    (previous, hasAccounts) {
      if (hasAccounts == null || hasAccounts == previous) return;
      unawaited(
        (hasAccounts ? scheduler.registerPeriodicSync() : scheduler.cancelAll())
            .then<void>(
              (_) {},
              onError: (Object error) => _log.warning(
                'Could not ${hasAccounts ? 'register' : 'cancel'} the '
                'background sync: ${error.runtimeType}',
              ),
            ),
      );
    },
    fireImmediately: true,
  );
}
