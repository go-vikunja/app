import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/account/user.dart';
import 'package:vikunja_domain/src/task/reactions.dart';

@immutable
final class TaskComment {
  const new({
    required this.id,
    required this.html,
    required this.author,
    this.created,
    this.updated,
    this.reactions = const {},
  });

  /// How much later than [created] [updated] must be to count as an edit:
  /// the server sets the two apart by a few nanoseconds and keeps whole
  /// seconds, so a fresh comment can read a second apart.
  static const editedAfter = Duration(seconds: 3);

  final int id;

  /// Untrusted rich text; render it through the sanitizer.
  final String html;
  final User author;
  final DateTime? created;
  final DateTime? updated;
  final Reactions reactions;

  bool get isEdited {
    final created = this.created;
    final updated = this.updated;
    return created != null &&
        updated != null &&
        updated.difference(created) > editedAfter;
  }

  static const _unset = Object();

  /// This comment with the given fields replaced; [created] and [updated]
  /// passed as null are cleared.
  TaskComment copyWith({
    String? html,
    User? author,
    Object? created = _unset,
    Object? updated = _unset,
    Reactions? reactions,
  }) => TaskComment(
    id: id,
    html: html ?? this.html,
    author: author ?? this.author,
    created: identical(created, _unset) ? this.created : created as DateTime?,
    updated: identical(updated, _unset) ? this.updated : updated as DateTime?,
    reactions: reactions ?? this.reactions,
  );

  @override
  bool operator ==(Object other) =>
      other is TaskComment &&
      other.id == id &&
      other.html == html &&
      other.author == author &&
      other.created == created &&
      other.updated == updated &&
      reactionsEqual(other.reactions, reactions);

  @override
  int get hashCode =>
      Object.hash(id, html, author, created, updated, reactionsHash(reactions));

  @override
  String toString() => 'TaskComment($id)';
}
