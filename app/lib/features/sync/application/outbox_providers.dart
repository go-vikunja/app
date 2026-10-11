import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/outbox/pending_task_ids_source.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

part 'outbox_providers.g.dart';

// After a switch, until the next account's stream has emitted, these carry
// the previous account's value; screens read them through unwrapPrevious().

/// Queued changes of the active account; 0 while nobody is signed in.
@Riverpod(keepAlive: true)
Stream<int> pendingChanges(Ref ref) =>
    ref.watch(taskRepositoryProvider)?.watchPendingChanges() ?? Stream.value(0);

@Riverpod(keepAlive: true)
Stream<List<SyncProblem>> syncProblems(Ref ref) =>
    ref.watch(taskRepositoryProvider)?.watchSyncProblems() ??
    Stream.value(const []);

/// Empty for a repository without a [PendingTaskIdsSource].
@Riverpod(keepAlive: true)
Stream<Set<int>> pendingTaskIds(Ref ref) =>
    switch (ref.watch(taskRepositoryProvider)) {
      final PendingTaskIdsSource source => source.watchPendingTaskIds(),
      _ => Stream.value(const {}),
    };
