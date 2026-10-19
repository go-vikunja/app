import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/dto/reaction_codec.dart';
import 'package:vikunja_api/src/dto/user_codec.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

const _unknownAuthor = User(id: 0, username: '');

/// `{id, comment, author, reactions, created, updated}`.
TaskComment parseTaskComment(Object? json) {
  final map = objectOf(json, 'comment');
  return TaskComment(
    id: requireInt(map, 'id', 'comment'),
    html: stringOr(map, 'comment', ''),
    author: parseUser(map['author']) ?? _unknownAuthor,
    created: dateOf(map['created']),
    updated: dateOf(map['updated']),
    reactions: parseReactions(map['reactions']),
  );
}
