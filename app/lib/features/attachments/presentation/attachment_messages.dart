import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/attachment_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/features/attachments/application/queue_attachments.dart';
import 'package:vikunja_mobile/features/common/presentation/file_size_text.dart';

/// Why an attachment action failed, as the user reads it; a [download]
/// changes nothing on the server.
String attachmentFailureText(
  AppLocalizations l10n,
  Object error, {
  bool download = false,
}) => switch (error) {
  UploadTooLarge(:final maxBytes) => l10n.attachmentFileTooLargeLimit(
    formatFileSize(l10n, maxBytes),
  ),
  FileTooLarge() => l10n.attachmentFileTooLarge,
  // The server may have done it before the answer was lost.
  NetworkFailure(problem: NetworkProblem.timeout) when !download =>
    l10n.attachmentUnconfirmed,
  NetworkFailure() => l10n.attachmentNeedsConnection,
  TaskNotSyncedYet() => l10n.attachmentNotSynced,
  Forbidden() when !download => l10n.attachmentForbidden,
  VikunjaFailure(code: 3008) => l10n.attachmentArchived,
  VikunjaFailure(code: 4011) => l10n.attachmentGone,
  NotFound(routeAbsent: true) => l10n.attachmentsDisabled,
  VikunjaFailure(:final message) when message.trim().isNotEmpty =>
    l10n.attachmentRefused(message.trim()),
  _ => l10n.attachmentFailed,
};

/// What adding files came to, null when nothing was given.
String? queuedAttachmentsText(AppLocalizations l10n, QueuedAttachments result) {
  final parts = [
    if (result.queued > 0) l10n.attachmentsQueued(result.queued),
    if (result.maxBytes case final maxBytes?)
      for (final name in result.tooLarge)
        l10n.attachmentTooLarge(name, formatFileSize(l10n, maxBytes)),
    for (final name in result.failed) l10n.attachmentAddFailed(name),
  ];
  return parts.isEmpty ? null : parts.join(' ');
}
