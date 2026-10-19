import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

/// Finds the task a link or a typed reference names, as the open sheets
/// need it: in the local database first (an id directly, an identifier
/// through the projects' identifiers and the tasks' indexes), otherwise
/// online, storing the task like a duplicate so that it survives until the
/// next sync decides. Throws the `VikunjaFailure`: `NotFound` for a task or
/// project that does not exist, `Forbidden` for one the user cannot read,
/// `NetworkFailure` when it is not local and the device is offline.
abstract interface class TaskResolver {
  Future<Task> resolve(TaskReference reference);

  /// The task when the local database has it, without a request; null
  /// otherwise. Lets a caller choose among accounts before going online.
  Future<Task?> findLocal(TaskReference reference);
}
