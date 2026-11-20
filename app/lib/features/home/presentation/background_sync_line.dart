import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/background/background_run_log.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/home/application/background_sync_status.dart';
import 'package:vikunja_mobile/features/home/presentation/session_end_text.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';

/// When the system last let the app sync this account in the background
/// successfully; the last attempt when it failed since; a hint when the
/// system has not run it for a day (Android), or that it decides when
/// (iOS, before the first run); and the account's last ended session,
/// while it is recent (D59).
class BackgroundSyncLine extends ConsumerWidget {
  const new({
    required this.accountId,
    required this.addedAt,
    required this.needsReauth,
    super.key,
  });

  final String accountId;

  /// Without any background run since, the idle hint counts from here.
  final DateTime addedAt;

  /// The reauth banner tells about the ended session then; once it is
  /// false again, the turns of the ended session are no longer shown.
  final bool needsReauth;

  /// How long the system may leave the background sync idle before the
  /// hint appears.
  static const idleHintAfter = Duration(hours: 24);

  /// How long after it ended a session end is still mentioned.
  static const sessionEndShownFor = Duration(days: 14);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(backgroundSyncStatusProvider(accountId));
    final value = status.value;
    if (value == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final now = ref.watch(clockTickProvider);
    String ago(DateTime at) => formatRelativeTime(l10n, at, now: now);

    final synced = value.lastSynced;
    final turn = value.lastTurn;
    final ended = value.lastSessionEnd;
    final failedTurn =
        turn != null &&
            turn.outcome != BackgroundAccountOutcome.synced &&
            (synced == null || !turn.at.isBefore(synced)) &&
            (needsReauth || !_ofEndedSession(turn, ended))
        ? turn
        : null;
    final idle =
        theme.platform == TargetPlatform.android &&
        now.difference(value.lastRun ?? addedAt) > idleHintAfter;
    final showEnd =
        !needsReauth &&
        ended != null &&
        now.difference(ended.at) < sessionEndShownFor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(switch (synced) {
          final at? when isJustNow(at, now: now) =>
            l10n.accountBackgroundSyncSucceededJustNow,
          final at? => l10n.accountBackgroundSyncSucceeded(ago(at)),
          null => l10n.accountBackgroundSyncNoneSucceeded,
        }, style: style),
        if (failedTurn case (:final outcome, :final at, :final stopReason))
          Text(switch (_failedOutcome(l10n, outcome, stopReason)) {
            final text when isJustNow(at, now: now) =>
              l10n.accountBackgroundTurnJustNow(text),
            final text => l10n.accountBackgroundTurn(ago(at), text),
          }, style: style),
        if (idle) Text(l10n.accountBackgroundSyncIdle, style: style),
        if (synced == null && theme.platform == TargetPlatform.iOS)
          Text(l10n.accountBackgroundSyncIosHint, style: style),
        if (showEnd)
          Text(
            [
              if (isJustNow(ended.at, now: now))
                l10n.accountLastSessionEndJustNow
              else
                l10n.accountLastSessionEnd(ago(ended.at)),
              describeSessionEndCause(l10n, ended, now: now),
              ?describeSessionEndResolution(l10n, ended.resolution),
            ].join(' '),
            style: style,
          ),
      ],
    );
  }

  /// Once the account works again (a new sign-in or a restore), a turn
  /// that ended the session, waited for a sign-in or came before the end
  /// tells of a session that is over.
  static bool _ofEndedSession(
    BackgroundTurn turn,
    SessionEndDiagnosis? ended,
  ) => switch (turn.outcome) {
    BackgroundAccountOutcome.sessionEnded ||
    BackgroundAccountOutcome.signInNeeded => true,
    _ => ended != null && turn.at.isBefore(ended.at),
  };

  static String _failedOutcome(
    AppLocalizations l10n,
    BackgroundAccountOutcome outcome,
    int? stopReason,
  ) => switch (outcome) {
    BackgroundAccountOutcome.synced => throw ArgumentError.value(
      outcome,
      'outcome',
      'not a failed turn',
    ),
    BackgroundAccountOutcome.unreachable =>
      l10n.accountBackgroundTurnUnreachable,
    BackgroundAccountOutcome.deferred => l10n.accountBackgroundTurnDeferred,
    BackgroundAccountOutcome.storageUnreadable =>
      l10n.accountBackgroundTurnStorageUnreadable,
    BackgroundAccountOutcome.failed => l10n.accountBackgroundTurnFailed,
    BackgroundAccountOutcome.sessionEnded =>
      l10n.accountBackgroundTurnSessionEnded,
    BackgroundAccountOutcome.signInNeeded =>
      l10n.accountBackgroundTurnSignInNeeded,
    BackgroundAccountOutcome.stopped => _stopped(l10n, stopReason),
  };

  /// Without a reason the run's own deadline stopped it. The periodic job
  /// needs a network and a battery that is not low; the other reasons say
  /// nothing a user can act on, and below Android 12, or from 10 on, the
  /// plugin reports 0.
  static String _stopped(AppLocalizations l10n, int? reason) =>
      switch (reason) {
        null => l10n.accountBackgroundTurnOutOfTime,
        _WorkInfoStopReason.timeout => l10n.accountBackgroundTurnStoppedTimeout,
        _WorkInfoStopReason.deviceState =>
          l10n.accountBackgroundTurnStoppedDeviceState,
        _WorkInfoStopReason.batteryNotLow =>
          l10n.accountBackgroundTurnStoppedBatteryLow,
        _WorkInfoStopReason.connectivity =>
          l10n.accountBackgroundTurnStoppedConnectivity,
        _ => l10n.accountBackgroundTurnStopped,
      };
}

/// Android's `WorkInfo.STOP_REASON_*` numbers that get words of their own.
abstract final class _WorkInfoStopReason {
  static const timeout = 3;
  static const deviceState = 4;
  static const batteryNotLow = 5;
  static const connectivity = 7;
}
