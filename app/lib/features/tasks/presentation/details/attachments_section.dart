import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
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
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/attachment_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/pending_upload_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/task_details_controller.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/attachment_image_viewer.dart';

final _log = Logger('TaskAttachments');

enum _Busy { downloading, deleting, saving }

/// The task's attachments: the queued uploads (offline too) above the ones
/// the server listed in [details], each with its menu. With [writable] and
/// a server that takes attachments, files, photos and camera shots can be
/// added, and attachments deleted or made the cover; opening, sharing and
/// saving work for everyone. Nothing shows while there is nothing to list
/// or add.
class TaskAttachmentsSection extends ConsumerStatefulWidget {
  const new({
    required this.task,
    required this.details,
    required this.controller,
    required this.writable,
    required this.onMessage,
    super.key,
  });

  final Task task;

  /// Null until the server's details are in.
  final TaskDetails? details;
  final TaskDetailsController controller;
  final bool writable;
  final ValueChanged<String> onMessage;

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
    if (mounted) setState(() => _queueing = true);
    try {
      final queued = await queueAttachments(repository, widget.task.id, [
        for (final file in picked.files)
          (path: file.path, name: file.name, mimeType: file.mimeType),
      ], moveSource: true);
      if (!mounted) return;
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
          description: attachment.name,
        ),
      );
      return;
    }
    unawaited(
      _withDownload(attachment, (file) async {
        final opened = await ref
            .read(fileActionsProvider)
            .openWith(
              file,
              mimeType: plainMimeType(attachment.mime),
              origin: origin,
            );
        if (!opened) _message((l10n) => l10n.attachmentNoApp);
      }),
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

  Future<void> _share(TaskAttachment attachment, Rect? origin) => _withDownload(
    attachment,
    (file) => ref
        .read(fileActionsProvider)
        .share(
          file,
          fileName: attachment.name,
          mimeType: plainMimeType(attachment.mime),
          origin: origin,
        ),
  );

  Future<void> _save(TaskAttachment attachment, Rect? origin) =>
      _withDownload(attachment, (file) async {
        final saved = await ref
            .read(fileActionsProvider)
            .saveAs(
              file,
              fileName: attachment.name,
              mimeType: plainMimeType(attachment.mime),
              origin: origin,
            );
        if (saved) _message((l10n) => l10n.attachmentSaved);
      });

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
      body: l10n.attachmentDeleteBody(attachment.name),
      confirmLabel: l10n.attachmentDeleteConfirm,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _change(attachment, _Busy.deleting, () async {
      await _attachments!.delete(
        widget.task.id,
        attachment.id,
        isCover: isCover,
      );
      widget.controller.removeAttachment(attachment.id);
      _message((l10n) => l10n.attachmentDeleted);
    });
  }

  /// Online, like the board's columns: applied here once the server has
  /// it, then the details are read again.
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

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading(
            onAdd: canChange && !_queueing
                ? (source) => unawaited(_add(source))
                : null,
          ),
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
              onOpen: canDownload
                  ? (origin) => _open(attachment, origin)
                  : null,
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
          if (_queueing)
            Semantics(
              label: l10n.attachmentAdd,
              child: const LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

/// The section's title with the menu of where to add files from.
class _Heading extends StatelessWidget {
  const new({required this.onAdd});

  final ValueChanged<AttachmentSource>? onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final heading = Semantics(
      header: true,
      child: Text(
        l10n.taskDetailAttachments,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
    final onAdd = this.onAdd;
    return Row(
      children: [
        Expanded(child: heading),
        if (onAdd != null)
          PopupMenuButton<AttachmentSource>(
            tooltip: l10n.attachmentAdd,
            icon: const Icon(Icons.add),
            onSelected: onAdd,
            itemBuilder: (context) =>
                attachmentSourceItems(l10n, AttachmentSource.values),
          )
        else
          const SizedBox(height: kMinInteractiveDimension),
      ],
    );
  }
}
