import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/attachments/upload_policy.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/attachment_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_attachment_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

part 'attachment_repository_providers.g.dart';

@riverpod
AttachmentRepository accountAttachmentRepository(Ref ref, String accountId) {
  final limits = ref.watch(
    accountsProvider.select((accounts) {
      final info = accounts.value?.find(accountId)?.connection.info;
      return info == null
          ? null
          : (
              enabled: info.taskAttachmentsEnabled,
              maxBytes: maxUploadBytesOf(info),
            );
    }),
  );
  if (limits == null) throw StateError('Account $accountId is not registered');
  return LocalAttachmentRepository(
    ref.watch(appDatabaseProvider(accountId)),
    ref.watch(readClientProvider(accountId)),
    ref.watch(writeClientProvider(accountId)),
    ref.watch(attachmentDownloadsProvider),
    accountId: accountId,
    uploadsEnabled: limits.enabled,
    maxUploadBytes: limits.maxBytes,
  );
}

/// The active account's; null while nobody is signed in.
@Riverpod(keepAlive: true)
AttachmentRepository? attachmentRepository(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  return ref.watch(accountAttachmentRepositoryProvider(accountId));
}
