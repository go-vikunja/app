import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/attachments/pending_upload.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

part 'attachment_providers.g.dart';

/// The task's queued uploads in the active account, failed ones included.
@riverpod
Stream<List<PendingUpload>> pendingUploads(Ref ref, int taskId) =>
    ref.watch(taskRepositoryProvider)?.watchPendingUploads(taskId) ??
    Stream.value(const []);
