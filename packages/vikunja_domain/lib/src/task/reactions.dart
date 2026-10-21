import 'package:vikunja_domain/src/account/user.dart';

/// Who reacted with which emoji (or short text, at most 20 characters), in
/// the server's key order. Empty when nobody reacted.
typedef Reactions = Map<String, List<User>>;

/// What a reaction is attached to, by the path segment of its routes
/// (`/tasks/{id}/reactions`, `/comments/{id}/reactions`).
enum ReactionEntity {
  task('tasks'),
  comment('comments');

  new(this.wireName);

  final String wireName;
}

/// The longest value the server takes, counted in code points (runes).
const int maxReactionLength = 20;

/// The same values with the same users in the same order; the order of the
/// values does not count.
bool reactionsEqual(Reactions a, Reactions b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final MapEntry(key: value, value: users) in a.entries) {
    final others = b[value];
    if (others == null || others.length != users.length) return false;
    for (var i = 0; i < users.length; i++) {
      if (users[i] != others[i]) return false;
    }
  }
  return true;
}

int reactionsHash(Reactions reactions) => Object.hashAllUnordered([
  for (final MapEntry(key: value, value: users) in reactions.entries)
    Object.hash(value, Object.hashAll(users)),
]);
