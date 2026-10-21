import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/attachment_image_view.dart';

IconData attachmentIcon(TaskAttachment attachment) =>
    attachmentIconFor(attachment.name, attachment.mime);

IconData attachmentIconFor(String name, String mime) {
  if (canPreviewAudio(mime)) return Icons.audiotrack_outlined;
  return switch (attachmentPreviewKind(name, mime)) {
    AttachmentPreviewKind.image => Icons.image_outlined,
    AttachmentPreviewKind.pdf => Icons.picture_as_pdf_outlined,
    AttachmentPreviewKind.video => Icons.movie_outlined,
    null => Icons.insert_drive_file_outlined,
  };
}

enum AttachmentAction { open, share, save, makeCover, removeCover, delete }

/// One attachment: a thumbnail for an image the server can preview, else
/// an icon of its kind, the name, the size and whether it is the cover. A
/// tap runs [onOpen] and the menu offers [actions], each told where the
/// row is on screen (an iPad anchors the share sheet there). While
/// [busyStatus] says what runs (a download, a delete, a cover change) the
/// row shows it in place of the size and takes no taps; [onCancel], when
/// given, stops it.
class AttachmentRow extends StatelessWidget {
  const new({
    required this.attachment,
    required this.isCover,
    this.onOpen,
    this.actions = const [],
    this.onAction,
    this.busyStatus,
    this.onCancel,
    super.key,
  });

  final TaskAttachment attachment;
  final bool isCover;
  final ValueChanged<Rect?>? onOpen;
  final List<AttachmentAction> actions;
  final void Function(AttachmentAction action, Rect? origin)? onAction;
  final String? busyStatus;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final image = canPreviewImage(attachment.name, attachment.mime);
    final icon = attachmentIcon(attachment);
    final onAction = this.onAction;
    final onOpen = this.onOpen;
    final onCancel = this.onCancel;
    final busyStatus = this.busyStatus;
    final busy = busyStatus != null;
    final trailing = busy && onCancel != null
        ? IconButton(
            onPressed: onCancel,
            tooltip: l10n.attachmentCancelDownload(attachment.name),
            icon: const Icon(Icons.close),
          )
        : busy
        ? const SizedBox.square(
            dimension: 48,
            child: Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              ),
            ),
          )
        : actions.isEmpty || onAction == null
        ? null
        : PopupMenuButton<AttachmentAction>(
            tooltip: l10n.attachmentOptions(attachment.name),
            icon: const Icon(Icons.more_vert),
            onSelected: (action) => onAction(action, _originOf(context)),
            itemBuilder: (context) => [
              for (final action in actions)
                PopupMenuItem(
                  value: action,
                  child: _ActionLabel(action: action),
                ),
            ],
          );
    // The menu stays its own node beside the row's.
    final row = MergeSemantics(
      child: ListTile(
        contentPadding: EdgeInsetsDirectional.only(
          start: 12,
          end: trailing == null ? 16 : 0,
        ),
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
              busyStatus ??
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
        onTap: busy || onOpen == null ? null : () => onOpen(_originOf(context)),
      ),
    );
    if (trailing == null) return row;
    return Row(
      children: [
        Expanded(child: row),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 4),
          child: trailing,
        ),
      ],
    );
  }

  static Rect? _originOf(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

class _ActionLabel extends StatelessWidget {
  const new({required this.action});

  final AttachmentAction action;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final destructive = action == AttachmentAction.delete;
    final (icon, label) = switch (action) {
      AttachmentAction.open => (Icons.open_in_new, l10n.attachmentOpen),
      AttachmentAction.share => (Icons.share_outlined, l10n.attachmentShare),
      AttachmentAction.save => (
        Icons.download_outlined,
        l10n.attachmentSaveToDevice,
      ),
      AttachmentAction.makeCover => (
        Icons.wallpaper_outlined,
        l10n.attachmentMakeCover,
      ),
      AttachmentAction.removeCover => (
        Icons.hide_image_outlined,
        l10n.attachmentRemoveCover,
      ),
      AttachmentAction.delete => (Icons.delete_outline, l10n.attachmentDelete),
    };
    return Row(
      children: [
        Icon(icon, color: destructive ? colors.error : null),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            style: destructive ? TextStyle(color: colors.error) : null,
          ),
        ),
      ],
    );
  }
}
