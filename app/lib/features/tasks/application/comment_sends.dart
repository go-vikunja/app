import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/storage/comment_drafts.dart';

part 'comment_sends.g.dart';

/// A comment on its way to the server: what the composer held and the
/// server's answer.
final class CommentSend {
  new(this.draft, this.result);

  final CommentComposerDraft draft;
  final Future<TaskComment> result;

  /// The details of the task opened since it went out that show it; while
  /// one does, it says how the send ended instead of the place below the
  /// detail that sent it.
  final shownIn = <Object>{};
}

/// The comments being sent, per account and task, beyond the detail that
/// sent them: one opened again before the server answered, or the sheet the
/// pane turns into, shows the comment as sending instead of offering its
/// kept draft to Send, which would post it twice. Only in memory.
final class CommentSends {
  final _sends = <(String, int), CommentSend>{};

  CommentSend? of(String account, int taskId) => _sends[(account, taskId)];

  void start(String account, int taskId, CommentSend send) =>
      _sends[(account, taskId)] = send;

  /// A later send of the task stays.
  void end(String account, int taskId, CommentSend send) {
    if (identical(_sends[(account, taskId)], send)) {
      _sends.remove((account, taskId));
    }
  }
}

@Riverpod(keepAlive: true)
CommentSends commentSends(Ref ref) => CommentSends();
