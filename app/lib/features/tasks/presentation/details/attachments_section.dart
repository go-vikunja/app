import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_dialog_action.dart';
import 'package:vikunja_mobile/core/attachments/pending_upload.dart';
import 'package:vikunja_mobile/core/attachments/upload_policy.dart';
import 'package:vikunja_mobile/core/files/file_actions.dart';
import 'package:vikunja_mobile/core/files/file_actions_providers.dart';
import 'package:vikunja_mobile/core/repositories/attachment_repository.dart';
import 'package:vikunja_mobile/core/repositories/attachment_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/attachments/application/attachment_picker.dart';
import 'package:vikunja_mobile/features/attachments/application/attachment_providers.dart';
import 'package:vikunja_mobile/features/attachments/application/queue_attachments.dart';
import 'package:vikunja_mobile/features/attachments/presentation/attachment_messages.dart';
import 'package:vikunja_mobile/features/attachments/presentation/attachment_source_items.dart';
import 'package:vikunja_mobile/features/attachments/presentation/location_kept_prompt.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/common/presentation/section_semantics.dart';
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/attachment_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/detail_section_header.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/detail_section_rows.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/pending_upload_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/task_details_controller.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/attachment_image_viewer.dart';

final _log = Logger('TaskAttachments');

enum _Busy { downloading, deleting, saving }

/// The task's attachments: the queued uploads (offline too) above the ones
/// the server listed in [details], each with its menu. With [writable] and
/// a server that takes attachments, files, photos and camera shots can be
/// added through the card's last row, alone while there is none, and
/// attachments made the cover, offline too, or deleted, which [offline]
/// shows disabled; opening, sharing and saving work for everyone. Nothing
/// shows while there is nothing to list or add.
class TaskAttachmentsSection extends ConsumerStatefulWidget {
  const new({
    required this.task,
    required this.details,
    required this.controller,
    required this.writable,
    required this.onMessage,
    this.offline = false,
    this.onMessageAfterClose,
    super.key,
  });

  final Task task;

  /// Null until the server's details are in.
  final TaskDetails? details;
  final TaskDetailsController controller;
  final bool writable;
  final bool offline;
  final ValueChanged<String> onMessage;

  /// For what is said once the section has gone, below the sheet.
  final ValueChanged<String>? onMessageAfterClose;

  @override
  ConsumerState<TaskAttachmentsSection> createState() =>
      _TaskAttachmentsSectionState();
}

class _TaskAttachmentsSectionState
    extends ConsumerState<TaskAttachmentsSection> {
  final _busy = <int, _Busy>{};
  final _downloads = <int, CancelToken>{};
  var _picking = false;
  var _queueing = false;

  AttachmentRepository? get _attachments =>
      ref.read(attachmentRepositoryProvider);

  @override
  void dispose() {
    for (final cancel in _downloads.values) {
      cancel.cancel();
    }
    super.dispose();
  }

  void _message(String Function(AppLocalizations l10n) text) {
    if (mounted) widget.onMessage(text(context.l10n));
  }

  /// The picked files are the pickers' own copies, so they move into the
  /// uploads; one that is not queued is deleted.
  Future<void> _add(AttachmentSource source) async {
    final repository = ref.read(taskRepositoryProvider);
    if (repository == null || _picking || _queueing) return;
    final l10n = context.l10n;
    final afterClose = widget.onMessageAfterClose;
    final maxBytes = _attachments?.maxUploadBytes ?? defaultMaxUploadBytes;
    _picking = true;
    final PickedFiles picked;
    try {
      picked = await ref
          .read(attachmentPickerProvider)
          .pick(source, maxBytes: maxBytes);
    } on Object catch (error) {
      _log.warning('Picking files failed: ${error.runtimeType}');
      _message((l10n) => l10n.attachmentPickFailed);
      return;
    } finally {
      _picking = false;
    }
    if (picked.isEmpty) return;
    // Queued even when the sheet closed meanwhile: the user picked them.
    // Those whose location stayed go only when the user says so, which a
    // closed sheet cannot ask; they are left out, and that is said below.
    if (mounted) setState(() => _queueing = true);
    try {
      final asked = mounted;
      final files = await withoutUnwantedLocations(
        asked ? context : null,
        picked.files,
      );
      final skipped = asked ? 0 : picked.files.length - files.length;
      final queued = await queueAttachments(repository, widget.task.id, [
        for (final file in files)
          (path: file.path, name: file.name, mimeType: file.mimeType),
      ], moveSource: true);
      if (!mounted) {
        if (skipped > 0) {
          afterClose?.call(l10n.attachmentLocationKeptLeftOut(skipped));
        }
        return;
      }
      final result = QueuedAttachments(
        queued: queued.queued,
        tooLarge: [...picked.tooLarge, ...queued.tooLarge],
        maxBytes: picked.tooLarge.isEmpty ? queued.maxBytes : maxBytes,
        failed: [...picked.failed, ...queued.failed],
      );
      if (queuedAttachmentsText(context.l10n, result) case final text?) {
        widget.onMessage(text);
      }
    } finally {
      if (mounted) setState(() => _queueing = false);
    }
  }

  /// The sources in a menu over [anchor], as a menu button opens one.
  Future<void> _pickSource(BuildContext anchor) async {
    final box = anchor.findRenderObject();
    final overlay = Navigator.of(anchor).overlay?.context.findRenderObject();
    if (box is! RenderBox || overlay is! RenderBox) return;
    final source = await showMenu<AttachmentSource>(
      context: anchor,
      position: RelativeRect.fromRect(
        box.localToGlobal(Offset.zero, ancestor: overlay) & box.size,
        Offset.zero & overlay.size,
      ),
      items: attachmentSourceItems(context.l10n, AttachmentSource.values),
    );
    if (source != null && mounted) unawaited(_add(source));
  }

  Future<void> _cancel(PendingUpload upload) async {
    try {
      await ref.read(taskRepositoryProvider)?.cancelUpload(upload.operationId);
    } on Object catch (error) {
      _log.warning('Cancelling an upload failed: ${error.runtimeType}');
    }
  }

  void _open(TaskAttachment attachment, Rect? origin) {
    if (canPreviewImage(attachment.name, attachment.mime)) {
      unawaited(
        showAttachmentImage(
          context,
          taskId: attachment.taskId,
          attachmentId: attachment.id,
          description: safeFileName(attachment.name),
        ),
      );
      return;
    }
    unawaited(
      _withDownload(attachment, (file) async {
        final result = await ref
            .read(fileActionsProvider)
            .openWith(
              file,
              mimeType: plainMimeType(attachment.mime),
              origin: origin,
            );
        switch (result) {
          case FileOpenResult.opened:
            return;
          case FileOpenResult.noApp:
            _message((l10n) => l10n.attachmentNoApp);
          case FileOpenResult.notViewable:
            if (!mounted) return;
            switch (await _askSaveOrShare()) {
              case AttachmentAction.save:
                await _saveFile(attachment, file, origin);
              case AttachmentAction.share:
                await _shareFile(attachment, file, origin);
              case _:
                return;
            }
        }
      }),
    );
  }

  Future<AttachmentAction?> _askSaveOrShare() {
    final l10n = context.l10n;
    return showAdaptiveDialog<AttachmentAction>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        scrollable: true,
        title: Text(l10n.attachmentNotViewableTitle),
        content: Text(l10n.attachmentNotViewableBody),
        actions: [
          AdaptiveDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          AdaptiveDialogAction(
            onPressed: () => Navigator.of(context).pop(AttachmentAction.share),
            child: Text(l10n.attachmentShare),
          ),
          AdaptiveDialogAction(
            onPressed: () => Navigator.of(context).pop(AttachmentAction.save),
            child: Text(l10n.attachmentSaveToDevice),
          ),
        ],
      ),
    );
  }

  /// [use] gets the original, downloaded to the cache (or still there);
  /// one download per attachment at a time, which the row can cancel and
  /// which stops when the sheet closes.
  Future<void> _withDownload(
    TaskAttachment attachment,
    Future<void> Function(File file) use,
  ) async {
    final attachments = _attachments;
    if (attachments == null || _busy.containsKey(attachment.id)) return;
    final cancel = CancelToken();
    setState(() {
      _busy[attachment.id] = _Busy.downloading;
      _downloads[attachment.id] = cancel;
    });
    final File file;
    try {
      file = await attachments.download(
        attachment.taskId,
        attachment,
        cancel: cancel,
      );
    } on Object catch (error) {
      if (cancel.isCancelled) return;
      _log.info('Downloading an attachment failed: ${error.runtimeType}');
      _message((l10n) => attachmentFailureText(l10n, error, download: true));
      return;
    } finally {
      _downloads.remove(attachment.id);
      if (mounted) setState(() => _busy.remove(attachment.id));
    }
    if (cancel.isCancelled || !mounted) return;
    try {
      await use(file);
    } on Object catch (error) {
      _log.warning('Handing an attachment on failed: ${error.runtimeType}');
      _message((l10n) => l10n.attachmentFailed);
    }
  }

  Future<void> _share(TaskAttachment attachment, Rect? origin) =>
      _withDownload(attachment, (file) => _shareFile(attachment, file, origin));

  Future<void> _shareFile(TaskAttachment attachment, File file, Rect? origin) =>
      ref
          .read(fileActionsProvider)
          .share(
            file,
            fileName: safeFileName(attachment.name),
            mimeType: plainMimeType(attachment.mime),
            origin: origin,
          );

  Future<void> _save(TaskAttachment attachment, Rect? origin) =>
      _withDownload(attachment, (file) => _saveFile(attachment, file, origin));

  Future<void> _saveFile(
    TaskAttachment attachment,
    File file,
    Rect? origin,
  ) async {
    final saved = await ref
        .read(fileActionsProvider)
        .saveAs(
          file,
          fileName: safeFileName(attachment.name),
          mimeType: plainMimeType(attachment.mime),
          origin: origin,
        );
    if (saved) _message((l10n) => l10n.attachmentSaved);
  }

  void _cancelDownload(TaskAttachment attachment) =>
      _downloads[attachment.id]?.cancel();

  Future<void> _setCover(TaskAttachment attachment, {required bool cover}) =>
      _change(attachment, _Busy.saving, () async {
        await _attachments!.setCover(
          widget.task.id,
          cover ? attachment.id : null,
        );
        widget.controller.setCover(cover ? attachment.id : 0);
        _message(
          (l10n) =>
              cover ? l10n.attachmentCoverSet : l10n.attachmentCoverRemoved,
        );
      });

  Future<void> _delete(
    TaskAttachment attachment, {
    required bool isCover,
  }) async {
    final l10n = context.l10n;
    final confirmed = await confirmAdaptive(
      context,
      title: l10n.attachmentDeleteTitle,
      body: l10n.attachmentDeleteBody(safeFileName(attachment.name)),
      confirmLabel: l10n.attachmentDeleteConfirm,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _change(attachment, _Busy.deleting, () async {
      // Read once: it follows the active account, and a read after an await
      // could send the delete to another account's server.
      final attachments = _attachments!;
      if (isCover) {
        // A step of its own: a delete that fails after it must still show
        // the cover gone, as the server will have it.
        await attachments.setCover(widget.task.id, null);
        widget.controller.setCover(0);
      }
      await attachments.delete(widget.task.id, attachment.id);
      widget.controller.removeAttachment(attachment.id);
      _message((l10n) => l10n.attachmentDeleted);
    });
  }

  /// A cover change is applied here once it is queued, a delete once the
  /// server has it; then the details are read again.
  Future<void> _change(
    TaskAttachment attachment,
    _Busy busy,
    Future<void> Function() change,
  ) async {
    if (_attachments == null || _busy.containsKey(attachment.id)) return;
    setState(() => _busy[attachment.id] = busy);
    try {
      await change();
      unawaited(widget.controller.refresh());
    } on Object catch (error) {
      _log.info('Changing an attachment failed: ${error.runtimeType}');
      _message((l10n) => attachmentFailureText(l10n, error));
    } finally {
      if (mounted) setState(() => _busy.remove(attachment.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final attachments = ref.watch(attachmentRepositoryProvider);
    final pending =
        ref.watch(pendingUploadsProvider(widget.task.id)).value ??
        const <PendingUpload>[];
    final listed = widget.details?.attachments ?? const <TaskAttachment>[];
    final canChange = widget.writable && (attachments?.uploadsEnabled ?? false);
    if (!canChange && pending.isEmpty && listed.isEmpty) {
      return const SizedBox.shrink();
    }
    // The server keeps the id of a deleted cover.
    final cover = widget.details?.coverImageAttachmentId ?? 0;
    final canDownload = attachments != null;

    final rows = [
      for (final upload in pending)
        PendingUploadRow(
          key: ValueKey(('upload', upload.operationId)),
          upload: upload,
          onCancel: () => unawaited(_cancel(upload)),
        ),
      for (final attachment in listed)
        AttachmentRow(
          key: ValueKey(('attachment', attachment.id)),
          attachment: attachment,
          isCover: attachment.id == cover,
          busyStatus: switch (_busy[attachment.id]) {
            _Busy.downloading => l10n.attachmentDownloading,
            _Busy.deleting => l10n.attachmentDeleting,
            _Busy.saving => l10n.attachmentSaving,
            null => null,
          },
          onCancel: _busy[attachment.id] == _Busy.downloading
              ? () => _cancelDownload(attachment)
              : null,
          onOpen: canDownload ? (origin) => _open(attachment, origin) : null,
          offline: widget.offline,
          actions: [
            if (canDownload) ...[
              AttachmentAction.open,
              AttachmentAction.share,
              AttachmentAction.save,
            ],
            if (canChange) ...[
              if (attachment.id == cover)
                AttachmentAction.removeCover
              // Kanban cards draw the cover as an image, as on the web.
              else if (canPreviewImage(attachment.name, attachment.mime))
                AttachmentAction.makeCover,
              AttachmentAction.delete,
            ],
          ],
          onAction: (action, origin) => switch (action) {
            AttachmentAction.open => _open(attachment, origin),
            AttachmentAction.share => unawaited(_share(attachment, origin)),
            AttachmentAction.save => unawaited(_save(attachment, origin)),
            AttachmentAction.makeCover => unawaited(
              _setCover(attachment, cover: true),
            ),
            AttachmentAction.removeCover => unawaited(
              _setCover(attachment, cover: false),
            ),
            AttachmentAction.delete => unawaited(
              _delete(attachment, isCover: attachment.id == cover),
            ),
          },
        ),
    ];
    return SectionSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailSectionHeader(title: l10n.taskDetailAttachments),
          SectionCard(
            children: [
              ...rows,
              if (canChange)
                Builder(
                  key: const ValueKey('add attachment'),
                  builder: (anchor) => DetailAddRow(
                    label: l10n.attachmentAdd,
                    onPressed: _queueing
                        ? null
                        : () => unawaited(_pickSource(anchor)),
                  ),
                ),
            ],
          ),
          if (_queueing)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Semantics(
                label: l10n.attachmentAdd,
                child: const LinearProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
