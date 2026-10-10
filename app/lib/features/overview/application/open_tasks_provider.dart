import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

part 'open_tasks_provider.g.dart';

/// Stays loading while no account is signed in.
@riverpod
Stream<List<Task>> openTasks(Ref ref) =>
    ref.watch(taskRepositoryProvider)?.watchOpenTasks() ?? const Stream.empty();
