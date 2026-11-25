import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_api/vikunja_api.dart'
    show AttachmentBlob, maxAttachmentBytes;
import 'package:vikunja_mobile/core/attachments/attachment_image_cache.dart';
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';
import 'package:vikunja_mobile/core/attachments/image_disk_cache.dart';
import 'package:vikunja_mobile/core/attachments/load_queue.dart';
import 'package:vikunja_mobile/core/files/file_actions.dart' show plainMimeType;
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

part 'attachment_image_providers.g.dart';

final _log = Logger('AttachmentImages');

/// `<cache>/images`, which holds a folder per account; backups leave the
/// cache folder out on both platforms.
@Riverpod(keepAlive: true)
Future<Directory> Function() imageDiskCacheRoot(Ref ref) =>
    () async => Directory(
      p.join(
        (await getApplicationCacheDirectory()).path,
        ImageDiskCache.folder,
      ),
    );

/// The account's attachment images and avatars on disk, shared by its two
/// memory caches. The account's sign-out deletes the folder
/// (`accountDataWiper`), and the start the folders of accounts the
/// registry does not know (`AccountDeletions.finishAll`).
@Riverpod(keepAlive: true)
ImageDiskCache accountImageDiskCache(Ref ref, String accountId) {
  final cache = ImageDiskCache.forAccount(
    ref.watch(imageDiskCacheRootProvider),
    accountId,
  );
  ref.onDispose(cache.close);
  return cache;
}

/// Kept for the session and dropped when the account signs out or another
/// becomes active ([inactiveAttachmentImages]); what is on disk stays. The
/// read client is looked up per request, like the avatar cache does. An
/// original in the download cache is read from there, offline too.
@Riverpod(keepAlive: true)
AttachmentImages accountAttachmentImages(Ref ref, String accountId) {
  final cache = AttachmentImageCache((
    taskId,
    attachmentId,
    preview,
    cancel,
  ) async {
    if (preview == null) {
      if (await _downloadedOriginal(ref, accountId, taskId, attachmentId)
          case final original?) {
        return original;
      }
    }
    return await ref
        .read(readClientProvider(accountId))
        .attachments
        .fetch(taskId, attachmentId, preview: preview, cancel: cancel);
  }, disk: ref.watch(accountImageDiskCacheProvider(accountId)));
  ref.onDispose(cache.clear);
  return cache;
}

/// The download cache names a file by the attachment's name and checks it
/// by its size, which only the details stored with the task know. One
/// larger than the read client takes is left to it to refuse.
Future<AttachmentBlob?> _downloadedOriginal(
  Ref ref,
  String accountId,
  int taskId,
  int attachmentId,
) async {
  try {
    final attachment = await ref
        .read(appDatabaseProvider(accountId))
        .taskDetailsDao
        .storedAttachment(taskId, attachmentId);
    if (attachment == null || attachment.size > maxAttachmentBytes) {
      return null;
    }
    final file = await ref
        .read(attachmentDownloadsProvider)
        .cached(accountId, taskId, attachment);
    if (file == null) return null;
    return AttachmentBlob(
      bytes: await file.readAsBytes(),
      contentType: plainMimeType(attachment.mime),
    );
  } on Object catch (error) {
    _log.info('Reading a downloaded original failed: ${error.runtimeType}');
    return null;
  }
}

/// Drops the previous account's images when another becomes active: only
/// the active account shows images, and each cache holds up to 32 MB.
/// Listened to from the start, as a provider nobody listens to is paused
/// with its listeners.
@Riverpod(keepAlive: true)
void inactiveAttachmentImages(Ref ref) {
  ref.listen(activeAccountIdProvider, (previous, next) {
    if (previous != null && previous != next) {
      ref.invalidate(accountAttachmentImagesProvider(previous));
    }
  });
}

/// The active account's; null while nobody is signed in.
@Riverpod(keepAlive: true)
AttachmentImages? attachmentImages(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  return ref.watch(accountAttachmentImagesProvider(accountId));
}

/// Inline images of descriptions and comments ask a few at a time,
/// app-wide (decision log: Descriptions, comments, attachments).
@Riverpod(keepAlive: true)
LoadQueue inlineImageQueue(Ref ref) => LoadQueue(maxRunning: 3);
