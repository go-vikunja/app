import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

enum CommentWrite { send, save, delete, react }

/// Why a comment or reaction write failed, as the user reads it.
String commentFailureText(
  AppLocalizations l10n,
  Object error,
  CommentWrite write,
) => switch (error) {
  // A comment may have arrived before the answer was lost; a reaction or
  // a deletion can simply be tried again.
  NetworkFailure(problem: NetworkProblem.timeout)
      when write == CommentWrite.send || write == CommentWrite.save =>
    l10n.commentFailedUnconfirmed,
  NetworkFailure() => l10n.commentFailedNeedsConnection,
  VikunjaFailure(code: 3008) => l10n.commentsArchivedNote,
  Forbidden() when write == CommentWrite.save || write == CommentWrite.delete =>
    l10n.commentFailedNotAuthor,
  Forbidden() => l10n.commentsReadOnlyNote,
  VikunjaFailure(code: 4015) => l10n.commentFailedGone,
  NotFound(taskGone: true) ||
  NotFound(projectGone: true) => l10n.taskOpenNotFound,
  // Empty comments never leave the app, so the server's 2002 is the size.
  VikunjaFailure(code: 2002) ||
  ServerFailure(statusCode: 413) ||
  UnexpectedResponse(
    statusCode: 413,
  ) when write != CommentWrite.react => l10n.commentFailedTooLong,
  _ => switch (write) {
    CommentWrite.send => l10n.commentFailedSend,
    CommentWrite.save => l10n.commentFailedSave,
    CommentWrite.delete => l10n.commentFailedDelete,
    CommentWrite.react => l10n.reactionFailed,
  },
};
