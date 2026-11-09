import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/activity/activity_providers.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/connection_refresh.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_controller.dart';
import 'package:vikunja_mobile/features/sync/application/foreground_sync_scheduler.dart';

part 'foreground_sync_scheduler_providers.g.dart';

/// The active account's scheduler, replaced on an account switch and gone
/// while nobody is signed in, while the session needs a new sign-in (a run
/// cannot reach the server) and during a sign-out (a run would race the
/// wipe). The shell listens; while nobody does (the first-sync screen, a
/// sign-out from there) the scheduler rests, because a provider without
/// listeners is not rebuilt either.
@Riverpod(keepAlive: true)
ForegroundSyncScheduler? foregroundSyncScheduler(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  final needsReauth = ref.watch(
    accountsProvider.select(
      (accounts) => accounts.value?.find(accountId)?.account.needsReauth,
    ),
  );
  if (needsReauth ?? true) return null;
  if (ref.watch(signOutControllerProvider)) return null;

  final activity = ref.watch(foregroundActivityProvider);
  final connectionRefresh = ref.watch(connectionRefreshProvider);
  final scheduler = ForegroundSyncScheduler(
    engine: ref.watch(syncEngineProvider(accountId)),
    clock: ref.watch(clockProvider),
    // The activity sync (step 16) and the re-read of /info (step 37e) ride
    // on its ticks.
    onForeground: ({required timed}) {
      activity.onForeground(timed: timed);
      unawaited(connectionRefresh.onForeground(accountId));
    },
  );
  var listened = true;
  bool inFront() => switch (WidgetsBinding.instance.lifecycleState) {
    null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
    _ => false,
  };
  final lifecycle = AppLifecycleListener(
    onResume: () {
      if (listened) scheduler.onResume();
    },
    onHide: scheduler.onPause,
    onPause: scheduler.onPause,
  );
  ref
    ..onDispose(() {
      lifecycle.dispose();
      scheduler.dispose();
    })
    ..onCancel(() {
      listened = false;
      scheduler.onPause();
    })
    ..onResume(() {
      listened = true;
      if (inFront()) scheduler.start();
    });
  if (inFront()) scheduler.start();
  return scheduler;
}
