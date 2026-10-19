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

  final int id;

  /// Untrusted rich text; render it through the sanitizer.
  final String html;
  final User author;
  final DateTime? created;
  final DateTime? updated;
  final Reactions reactions;

  /// The web's rule: both times are known and differ.
  bool get isEdited {
    final created = this.created;
    final updated = this.updated;
    return created != null &&
        updated != null &&
        created.millisecondsSinceEpoch != updated.millisecondsSinceEpoch;
  }

  @override
  bool operator ==(Object other) =>
      other is TaskComment &&
      other.id == id &&
      other.html == html &&
      other.author == author &&
      other.created == created &&
      other.updated == updated;

  @override
  int get hashCode => Object.hash(id, html, author, created, updated);

  @override
  String toString() => 'TaskComment($id)';
}
