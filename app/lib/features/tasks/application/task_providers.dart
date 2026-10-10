import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

part 'task_providers.g.dart';

/// One task as the local row knows it, following a queued create across
/// its id change; null once the row is gone. Stays loading without an
/// account.
@riverpod
Stream<Task?> taskById(Ref ref, int taskId) =>
    ref.watch(taskRepositoryProvider)?.watchTask(taskId) ??
    const Stream.empty();
