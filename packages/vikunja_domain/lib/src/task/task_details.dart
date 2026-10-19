import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/task/reactions.dart';
import 'package:vikunja_domain/src/task/subscription.dart';
import 'package:vikunja_domain/src/task/task_attachment.dart';

/// What only a single task read carries and the sync does not store:
/// read on demand, online.
@immutable
final class TaskDetails {
  const new({
    this.attachments = const [],
    this.coverImageAttachmentId = 0,
    this.reactions = const {},
    this.commentCount = 0,
    this.isUnread = false,
    this.subscription,
  });

  final List<TaskAttachment> attachments;

  /// 0 for none. May name an attachment that is gone: the server leaves
  /// the id behind when the cover is deleted.
  final int coverImageAttachmentId;
  final Reactions reactions;
  final int commentCount;

  /// A comment by someone else arrived since the user last opened the task.
  final bool isUnread;

  /// Own or inherited from the project; null when not subscribed.
  final Subscription? subscription;
}
