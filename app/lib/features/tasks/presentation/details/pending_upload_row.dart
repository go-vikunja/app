import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/attachments/pending_upload.dart';
import 'package:vikunja_mobile/features/common/presentation/file_size_text.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/attachment_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/attachment_image_view.dart';

/// A file queued for upload: waiting (offline, behind the task's create),
/// uploading, with an indeterminate progress (the transport sends the body
/// in one piece), or refused, which the Sync problems explain. Cancel
/// drops it and its stored copy.
class PendingUploadRow extends StatelessWidget {
  const new({required this.upload, required this.onCancel, super.key});

  final PendingUpload upload;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final failed = upload.state == PendingUploadState.failed;
    final status = switch (upload.state) {
      PendingUploadState.waiting => l10n.attachmentWaiting,
      PendingUploadState.sending => l10n.attachmentUploading,
      PendingUploadState.failed => switch (upload.lastFailure) {
        FileTooLarge() => l10n.attachmentUploadTooLarge,
        _ => l10n.attachmentUploadFailed,
      },
    };
    final row = MergeSemantics(
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.only(start: 12),
        leading: ExcludeSemantics(
          child: AttachmentIcon(
            icon: attachmentIconFor(upload.fileName, upload.mimeType ?? ''),
          ),
        ),
        title: Text(upload.fileName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$status · ${formatFileSize(l10n, upload.size)}',
              style: failed ? TextStyle(color: colors.error) : null,
            ),
            if (upload.state == PendingUploadState.sending)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        Expanded(child: row),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 4),
          child: IconButton(
            onPressed: onCancel,
            tooltip: l10n.attachmentCancelUpload(upload.fileName),
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    );
  }
}
