import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/project/permission.dart';
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
    this.maxPermission,
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

  /// The user's permission on the task's project; null when the server
  /// does not tell (v1). It stays `admin` for the owner of an archived
  /// project, which refuses every write all the same.
  final Permission? maxPermission;

  static const _unset = Object();

  /// These details with the given fields replaced; [subscription] and
  /// [maxPermission] passed as null are cleared.
  TaskDetails copyWith({
    List<TaskAttachment>? attachments,
    int? coverImageAttachmentId,
    Reactions? reactions,
    int? commentCount,
    bool? isUnread,
    Object? subscription = _unset,
    Object? maxPermission = _unset,
  }) => TaskDetails(
    attachments: attachments ?? this.attachments,
    coverImageAttachmentId:
        coverImageAttachmentId ?? this.coverImageAttachmentId,
    reactions: reactions ?? this.reactions,
    commentCount: commentCount ?? this.commentCount,
    isUnread: isUnread ?? this.isUnread,
    subscription: identical(subscription, _unset)
        ? this.subscription
        : subscription as Subscription?,
    maxPermission: identical(maxPermission, _unset)
        ? this.maxPermission
        : maxPermission as Permission?,
  );
}
