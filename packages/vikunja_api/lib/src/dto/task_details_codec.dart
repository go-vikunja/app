import 'package:vikunja_api/src/dto/attachment_codec.dart';
import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/dto/reaction_codec.dart';
import 'package:vikunja_api/src/dto/subscription_codec.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// The parts of a single task read with `expand=reactions`,
/// `comment_count` and `is_unread` that the sync does not keep.
/// `is_unread` is only ever `true` or absent.
TaskDetails parseTaskDetails(Object? json) {
  final map = objectOf(json, 'task');
  final taskId = requireInt(map, 'id', 'task');
  return TaskDetails(
    attachments: List.unmodifiable(
      objectListOf(map['attachments'])
          .map((json) => parseTaskAttachment(json, taskId: taskId))
          .nonNulls,
    ),
    coverImageAttachmentId: intOr(map, 'cover_image_attachment_id', 0),
    reactions: parseReactions(map['reactions']),
    commentCount: intOr(map, 'comment_count', 0),
    isUnread: map['is_unread'] == true,
    subscription: subscriptionOf(map),
  );
}
