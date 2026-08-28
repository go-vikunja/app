import 'dart:io';

import 'package:background_downloader/background_downloader.dart'
    show FileDownloader, TaskStatus;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_attachment.dart';
import 'package:vikunja_app/presentation/pages/attachment/html_viewer_page.dart';
import 'package:vikunja_app/presentation/pages/attachment/pdf_viewer_page.dart';

bool isPdfAttachment(TaskAttachment attachment) {
  final mime = attachment.file.mime.toLowerCase();
  final name = attachment.file.name.toLowerCase();
  return mime.contains('pdf') || name.endsWith('.pdf');
}

bool isHtmlAttachment(TaskAttachment attachment) {
  final mime = attachment.file.mime.toLowerCase();
  final name = attachment.file.name.toLowerCase();
  return mime.contains('html') ||
      name.endsWith('.html') ||
      name.endsWith('.htm');
}

IconData attachmentIcon(TaskAttachment attachment) {
  if (isPdfAttachment(attachment)) {
    return Icons.picture_as_pdf;
  }
  if (isHtmlAttachment(attachment)) {
    return Icons.code;
  }
  if (attachment.file.mime.toLowerCase().startsWith('image/')) {
    return Icons.image;
  }
  return Icons.insert_drive_file;
}

String attachmentSizeLabel(TaskAttachment attachment) {
  final size = attachment.file.size;
  if (size >= 1024 * 1024) {
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (size >= 1024) {
    return '${(size / 1024).toStringAsFixed(0)} KB';
  }
  return '$size B';
}

/// Resolves the local path for an attachment, downloading it first if it is
/// not already cached on device. Returns null on failure.
Future<String?> resolveAttachmentPath(
  WidgetRef ref,
  Task task,
  TaskAttachment attachment,
) async {
  try {
    final cached = await ref
        .read(taskRepositoryProvider)
        .getAttachmentFilePath(task.id, attachment);
    if (cached != null && File(cached).existsSync()) {
      return cached;
    }

    final update = await ref
        .read(taskRepositoryProvider)
        .downloadAttachment(task.id, attachment);
    if (update.status == TaskStatus.complete) {
      final path = await update.task.filePath();
      if (File(path).existsSync()) {
        return path;
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

/// Downloads the attachment and hands it to an external viewer.
Future<bool> openAttachmentExternally(
  WidgetRef ref,
  Task task,
  TaskAttachment attachment,
) async {
  try {
    final update = await ref
        .read(taskRepositoryProvider)
        .downloadAttachment(task.id, attachment);
    if (update.status == TaskStatus.complete) {
      return await FileDownloader().openFile(task: update.task);
    }
  } catch (_) {
    return false;
  }
  return false;
}

/// Opens an already-downloaded local file in an external app (via the
/// downloader, which exposes the file through a content URI).
Future<bool> openLocalFileExternally(String path, String mime) {
  return FileDownloader().openFile(filePath: path, mimeType: mime);
}

/// Opens an attachment: PDFs render in the in-app PDF viewer, HTML files in
/// the in-app HTML viewer, everything else opens in an external app.
void openAttachment(
  BuildContext context,
  WidgetRef ref,
  Task task,
  TaskAttachment attachment,
) {
  if (isPdfAttachment(attachment)) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(task: task, attachment: attachment),
      ),
    );
  } else if (isHtmlAttachment(attachment)) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HtmlViewerPage(task: task, attachment: attachment),
      ),
    );
  } else {
    openAttachmentExternally(ref, task, attachment);
  }
}
