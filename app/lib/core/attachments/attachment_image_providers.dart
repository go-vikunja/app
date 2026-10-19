import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/attachments/attachment_image_cache.dart';
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

part 'attachment_image_providers.g.dart';

/// Kept for the session and dropped when the account signs out. The read
/// client is looked up per request, like the avatar cache does.
@Riverpod(keepAlive: true)
AttachmentImages accountAttachmentImages(Ref ref, String accountId) {
  final cache = AttachmentImageCache(
    (taskId, attachmentId, preview) => ref
        .read(readClientProvider(accountId))
        .attachments
        .fetch(taskId, attachmentId, preview: preview),
  );
  ref.onDispose(cache.clear);
  return cache;
}

/// The active account's; null while nobody is signed in.
@Riverpod(keepAlive: true)
AttachmentImages? attachmentImages(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  return ref.watch(accountAttachmentImagesProvider(accountId));
}
