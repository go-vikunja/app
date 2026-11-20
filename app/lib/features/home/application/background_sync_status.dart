import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/background/background_providers.dart';
import 'package:vikunja_mobile/core/background/background_run_log.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';

part 'background_sync_status.g.dart';

/// What the background sync last did for an account, and when the
/// account's session last ended (D59).
typedef BackgroundSyncStatus = ({
  /// The last background run whose sync went through; null before.
  DateTime? lastSynced,

  /// The account's last turn, whatever came of it.
  BackgroundTurn? lastTurn,

  /// The last background run of any account, skipped ones included.
  DateTime? lastRun,

  SessionEndDiagnosis? lastSessionEnd,
});

/// Other isolates write all of it, so it is read again every minute while
/// the app is in front and when it comes back.
@riverpod
Future<BackgroundSyncStatus> backgroundSyncStatus(
  Ref ref,
  String accountId,
) async {
  ref.watch(clockTickProvider);
  final log = ref.watch(backgroundRunLogProvider);
  return (
    lastSynced: await log.lastRunAt(accountId),
    lastTurn: await log.lastOutcome(accountId),
    lastRun: (await log.lastResult())?.at,
    lastSessionEnd: await ref
        .watch(sessionDiagnosticsProvider)
        .lastEnd(accountId),
  );
}

/// The account's last session end, read while the account's sign-in mark
/// was `needsReauth`.
typedef MarkedSessionEnd = ({bool needsReauth, SessionEndDiagnosis? end});

/// Read again whenever the account's sign-in mark flips, as an end is
/// recorded before the mark (D59), and every minute for other isolates'
/// records. A value read before the mark tells nothing about its end.
@riverpod
Future<MarkedSessionEnd> markedSessionEnd(Ref ref, String accountId) async {
  ref.watch(clockTickProvider);
  final needsReauth = ref.watch(
    accountsProvider.select(
      (accounts) => accounts.value?.find(accountId)?.account.needsReauth,
    ),
  );
  return (
    needsReauth: needsReauth ?? false,
    end: await ref.watch(sessionDiagnosticsProvider).lastEnd(accountId),
  );
}
