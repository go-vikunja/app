import 'package:vikunja_domain/vikunja_domain.dart';

/// [task] as the local row looks right after a done toggle, for a list that
/// keeps the row on screen while its Undo snackbar is up.
Task withDone(Task task, {required bool done, required DateTime now}) =>
    task.copyWith(done: done, doneAt: done ? now : null);
