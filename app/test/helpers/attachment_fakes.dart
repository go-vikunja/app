import 'dart:async';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/files/file_actions.dart';
import 'package:vikunja_mobile/core/repositories/attachment_repository.dart';
import 'package:vikunja_mobile/core/share/share_intent_source.dart';

/// The server's attachments as the repository reaches them, without a
/// network. Every call is recorded in [calls] (`delete 3 7`,
/// `delete 3 7 cover`, `setCover 3 7`, `setCover 3 null`, `download 3 7`,
/// `uploadNow 3 photo.png`); [beforeCall] can hold or fail one, and
/// [failure] fails every call while set (a `VikunjaFailure`,
/// `TaskNotSyncedYet` or `UploadTooLarge`). [download] answers
/// `<downloadDirectory>/<task>/<id>/<name>` without writing anything unless
/// [downloads] has a file for the attachment id; [uploadNow] answers the
/// next id from [nextAttachmentId]
/// with the size from [uploadSizes] by file path (0 when absent) and
/// refuses a size above [maxUploadBytes] with `UploadTooLarge`. The cancel
/// tokens handed in are kept in [cancelTokens].
final class FakeAttachmentRepository implements AttachmentRepository {
  @override
  bool uploadsEnabled = true;

  @override
  int maxUploadBytes = 20 * 1024 * 1024;

  final List<String> calls = [];
  Exception? failure;
  Future<void> Function(String call)? beforeCall;

  String downloadDirectory = '/cache/attachments';
  final Map<int, File> downloads = {};

  int nextAttachmentId = 500;
  final Map<String, int> uploadSizes = {};
  final List<TaskAttachment> uploaded = [];
  final List<CancelToken?> cancelTokens = [];

  /// The cover per task id as the server holds it after [setCover] and
  /// [delete] (0: none).
  final Map<int, int> covers = {};

  @override
  Future<void> delete(
    int taskId,
    int attachmentId, {
    bool isCover = false,
  }) async {
    await _call('delete $taskId $attachmentId${isCover ? ' cover' : ''}');
    if (isCover || covers[taskId] == attachmentId) covers[taskId] = 0;
  }

  @override
  Future<void> setCover(int taskId, int? attachmentId) async {
    await _call('setCover $taskId $attachmentId');
    covers[taskId] = attachmentId ?? 0;
  }

  @override
  Future<File> download(
    int taskId,
    TaskAttachment attachment, {
    CancelToken? cancel,
  }) async {
    cancelTokens.add(cancel);
    await _call('download $taskId ${attachment.id}');
    return downloads[attachment.id] ??
        File('$downloadDirectory/$taskId/${attachment.id}/${attachment.name}');
  }

  @override
  Future<TaskAttachment> uploadNow(
    int taskId,
    File file, {
    required String fileName,
    String? mimeType,
    CancelToken? cancel,
  }) async {
    cancelTokens.add(cancel);
    final size = uploadSizes[file.path] ?? 0;
    if (size > maxUploadBytes) {
      throw UploadTooLarge(size: size, maxBytes: maxUploadBytes);
    }
    await _call('uploadNow $taskId $fileName');
    final attachment = TaskAttachment(
      id: nextAttachmentId++,
      taskId: taskId,
      name: fileName,
      mime: mimeType ?? '',
      size: size,
    );
    uploaded.add(attachment);
    return attachment;
  }

  Future<void> _call(String call) async {
    calls.add(call);
    await beforeCall?.call(call);
    if (failure case final failure?) throw failure;
  }
}

/// Records every action in [calls] (`openWith <path> <mime>`,
/// `saveAs <path> <name> <mime>`, `share <path> <name> <mime>`) with its
/// share sheet anchor in [origins]; [openWith] answers [canOpen], [saveAs]
/// answers [saveConfirmed]; [beforeCall] can hold or fail one and
/// [failure] fails every call while set.
final class FakeFileActions implements FileActions {
  final List<String> calls = [];
  final List<Rect?> origins = [];
  bool canOpen = true;
  bool saveConfirmed = true;
  Exception? failure;
  Future<void> Function(String call)? beforeCall;

  @override
  Future<bool> openWith(
    File file, {
    required String mimeType,
    Rect? origin,
  }) async {
    await _call('openWith ${file.path} $mimeType', origin);
    return canOpen;
  }

  @override
  Future<bool> saveAs(
    File file, {
    required String fileName,
    required String mimeType,
    Rect? origin,
  }) async {
    await _call('saveAs ${file.path} $fileName $mimeType', origin);
    return saveConfirmed;
  }

  @override
  Future<void> share(
    File file, {
    required String fileName,
    required String mimeType,
    Rect? origin,
  }) => _call('share ${file.path} $fileName $mimeType', origin);

  Future<void> _call(String call, Rect? origin) async {
    calls.add(call);
    origins.add(origin);
    await beforeCall?.call(call);
    if (failure case final failure?) throw failure;
  }
}

/// `initial` is the share waiting at start; [push] delivers one while the
/// app runs (it becomes the pending one, as on the platform). [copy]
/// answers [copies] by URI, fails with [copyFailures] by URI, refuses a
/// file whose known size is above `maxBytes` with `SharedFileTooLarge`,
/// and else answers `/cache/share-inbox/<n>` with the file's size (0 when
/// unknown); a URI that is not in the pending share is
/// `SharedFileUnreadable`, as on the platform. [clear] forgets the pending
/// share. Every call is recorded in [calls] (`pending`,
/// `copy <uri> max <bytes>`, `clear`); [beforeCall] can hold or fail one.
final class FakeShareIntentSource implements ShareIntentSource {
  new({IncomingShare? initial}) : _pending = initial;

  IncomingShare? _pending;
  final controller = StreamController<IncomingShare>.broadcast();
  final Map<String, CopiedSharedFile> copies = {};
  final Map<String, Exception> copyFailures = {};
  final List<String> calls = [];
  final List<String> copiedPaths = [];
  Future<void> Function(String call)? beforeCall;
  var _nextCopy = 1;

  IncomingShare? get pendingShare => _pending;

  void push(IncomingShare share) {
    _pending = share;
    controller.add(share);
  }

  @override
  Future<IncomingShare?> pending() async {
    await _call('pending');
    return _pending;
  }

  @override
  Stream<IncomingShare> get shares => controller.stream;

  @override
  Future<CopiedSharedFile> copy(String uri, {required int maxBytes}) async {
    await _call('copy $uri max $maxBytes');
    if (copyFailures[uri] case final failure?) throw failure;
    final file = _pending?.files.where((file) => file.uri == uri).firstOrNull;
    if (file == null) throw const SharedFileUnreadable();
    if ((file.size ?? 0) > maxBytes) {
      throw SharedFileTooLarge(maxBytes: maxBytes);
    }
    final copied =
        copies[uri] ??
        CopiedSharedFile(
          path: '/cache/share-inbox/${_nextCopy++}',
          size: file.size ?? 0,
        );
    copiedPaths.add(copied.path);
    return copied;
  }

  @override
  Future<void> clear() async {
    await _call('clear');
    _pending = null;
  }

  Future<void> _call(String call) async {
    calls.add(call);
    await beforeCall?.call(call);
  }
}
