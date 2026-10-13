import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';

part 'overview_tasks_provider.g.dart';

/// Stays loading while no account is signed in.
@riverpod
Stream<OverviewTasks> overviewTasks(Ref ref) =>
    ref.watch(taskRepositoryProvider)?.watchOverviewTasks() ??
    const Stream.empty();
