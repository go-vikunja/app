import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/attachments/attachment_image_cache.dart';
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

part 'attachment_image_providers.g.dart';

/// Kept for the session and dropped when the account signs out or another
/// becomes active ([inactiveAttachmentImages]). The read client is looked
/// up per request, like the avatar cache does.
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
