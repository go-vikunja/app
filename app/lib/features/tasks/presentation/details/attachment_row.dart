import 'dart:async';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/attachment_image_view.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/attachment_image_viewer.dart';

IconData attachmentIcon(TaskAttachment attachment) {
  if (canPreviewAudio(attachment.mime)) return Icons.audiotrack_outlined;
  return switch (attachmentPreviewKind(attachment.name, attachment.mime)) {
    AttachmentPreviewKind.image => Icons.image_outlined,
    AttachmentPreviewKind.pdf => Icons.picture_as_pdf_outlined,
    AttachmentPreviewKind.video => Icons.movie_outlined,
    null => Icons.insert_drive_file_outlined,
  };
}

/// One attachment: a thumbnail for an image the server can preview, else
/// an icon of its kind, the name, the size and whether it is the cover.
/// An image opens full screen; other files are only listed.
class AttachmentRow extends StatelessWidget {
  const new({required this.attachment, required this.isCover, super.key});

  final TaskAttachment attachment;
  final bool isCover;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final image = canPreviewImage(attachment.name, attachment.mime);
    final icon = attachmentIcon(attachment);
    return MergeSemantics(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: ExcludeSemantics(
          child: image
              ? AttachmentThumbnail(
                  taskId: attachment.taskId,
                  attachmentId: attachment.id,
                  fallbackIcon: icon,
                )
              : AttachmentIcon(icon: icon),
        ),
        title: Text(attachment.name),
        subtitle: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              humanSize(
                attachment.size,
                formatNumber: NumberFormat.decimalPattern(l10n.localeName)
                    .format,
              ),
            ),
            if (isCover)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    l10n.taskDetailCoverImage,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
          ],
        ),
        onTap: image
            ? () => unawaited(
                showAttachmentImage(
                  context,
                  taskId: attachment.taskId,
                  attachmentId: attachment.id,
                  description: attachment.name,
                ),
              )
            : null,
      ),
    );
  }
}
