import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_write_access.g.dart';

/// Whether the signed-in user may change a task, as the last read of its
/// details in this run of the app said, so that a sheet opened again knows
/// before its own read arrives, also offline. Only in memory.
final class TaskWriteAccess {
  final _writable = <(String, int), bool>{};

  bool? writable(String account, int taskId) => _writable[(account, taskId)];

  void remember(String account, int taskId, {required bool writable}) =>
      _writable[(account, taskId)] = writable;
}

@Riverpod(keepAlive: true)
TaskWriteAccess taskWriteAccess(Ref ref) => TaskWriteAccess();
