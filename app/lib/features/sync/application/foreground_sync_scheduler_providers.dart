import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/activity/activity_providers.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/connection_refresh.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
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
    dataWrites: ref.watch(accountDataWritesProvider(accountId)),
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

/// What a run that found something new stores, and every local write:
/// the account's tasks, projects, labels and queued changes. A run that
/// finds nothing new writes none of them (D33), so the foreground sync can
/// wait longer then.
@Riverpod(keepAlive: true)
Raw<Stream<void>> accountDataWrites(Ref ref, String accountId) =>
    dataWritesOf(ref.watch(appDatabaseProvider(accountId)));

/// A fresh subscription for every listener, as a rebuilt scheduler listens
/// again to the provider's kept stream.
Stream<void> dataWritesOf(AppDatabase db) => everyListener(
  () => db.tableUpdates(
    TableUpdateQuery.onAllTables([db.tasks, db.projects, db.labels, db.outbox]),
  ),
);

Stream<void> everyListener(Stream<Object?> Function() source) =>
    Stream<void>.multi((listener) {
      final subscription = source().listen((_) => listener.add(null));
      listener.onCancel = subscription.cancel;
    });
