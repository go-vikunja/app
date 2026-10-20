import 'dart:math';

import 'package:vikunja_domain/vikunja_domain.dart';

/// What the server enforces when `/info` names no usable limit.
const int defaultMaxUploadBytes = 20 * 1024 * 1024;

/// The largest file the app uploads, whatever the server takes: the native
/// transports hold the whole body in memory two or three times over, and
/// it must go within [maxUploadTimeout] on a modest uplink (1.7 Mbit/s).
const int appMaxUploadBytes = 50 * 1024 * 1024;

/// The server's upload limit as `/info` reports it, else its default; at
/// most [appMaxUploadBytes].
int maxUploadBytesOf(ServerInfo info) {
  final serverLimit = switch (info.maxFileSizeBytes) {
    final bytes? when bytes > 0 => bytes,
    _ => defaultMaxUploadBytes,
  };
  return min(serverLimit, appMaxUploadBytes);
}

/// How long one upload of [bytes] may take for sending and, again, for the
/// answer: half a minute plus the file at a slow mobile uplink, at least a
/// minute. At most four, so a live upload never reaches the outbox's reset
/// of stuck sends; the default timeouts would cut most uploads off.
Duration uploadTimeoutFor(int bytes) {
  final estimate = Duration(seconds: 30 + bytes ~/ _slowUplinkBytesPerSecond);
  if (estimate < _minUploadTimeout) return _minUploadTimeout;
  if (estimate > maxUploadTimeout) return maxUploadTimeout;
  return estimate;
}

const int _slowUplinkBytesPerSecond = 32 * 1024;
const _minUploadTimeout = Duration(minutes: 1);
const maxUploadTimeout = Duration(minutes: 4);

/// How many times in a row an upload may time out before it becomes a sync
/// problem: a link too slow for the file would otherwise resend it for
/// good.
const int maxUploadTimeoutsInARow = 3;

/// The `last_error` of an upload whose stored copy is gone; it can never be
/// sent.
const uploadFileMissingMessage = 'the stored copy of the file is missing';

/// Why a queued upload failed for good, for the sync problem's text.
enum UploadProblemReason {
  /// Above the server's limit; [maxUploadBytesOf] says how much it takes.
  tooLarge,

  /// The task is gone on the server, or no longer visible to the user.
  taskGone,
  projectArchived,

  /// A read-only share, or the user lost write access.
  noPermission,

  /// The server has attachments switched off.
  attachmentsDisabled,

  /// The stored copy is gone; only Discard helps.
  fileMissing,

  /// Timed out [maxUploadTimeoutsInARow] times in a row.
  timedOut,
  other,
}

UploadProblemReason uploadProblemReason(VikunjaFailure failure) =>
    switch (failure) {
      FileTooLarge() => UploadProblemReason.tooLarge,
      DomainError(code: 4012 || 4035) => UploadProblemReason.tooLarge,
      DomainError(code: 3008) => UploadProblemReason.projectArchived,
      NotFound(:final routeAbsent) when routeAbsent =>
        UploadProblemReason.attachmentsDisabled,
      NotFound() => UploadProblemReason.taskGone,
      Forbidden() => UploadProblemReason.noPermission,
      UnexpectedResponse(statusCode: null, :final message)
          when message == uploadFileMissingMessage =>
        UploadProblemReason.fileMissing,
      NetworkFailure(problem: NetworkProblem.timeout) =>
        UploadProblemReason.timedOut,
      _ => UploadProblemReason.other,
    };
