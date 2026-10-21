import 'package:vikunja_domain/vikunja_domain.dart';

/// [reactions] with [me] added to or removed from [value], keeping every
/// other value and user in its place as the web does; [me] goes last in a
/// value, a new value goes last, one nobody is left in goes.
Reactions toggledReaction(
  Reactions reactions,
  String value, {
  required User me,
  required bool add,
}) {
  final users = reactions[value] ?? const <User>[];
  final mine = users.any((user) => user.id == me.id);
  if (mine == add) return reactions;
  final changed = add
      ? [...users, me]
      : [
          for (final user in users)
            if (user.id != me.id) user,
        ];
  return {
    for (final MapEntry(:key, value: others) in reactions.entries)
      if (key != value) key: others else if (changed.isNotEmpty) key: changed,
    if (!reactions.containsKey(value) && changed.isNotEmpty) value: changed,
  };
}

/// Whether [me] reacted with [value].
bool reactedWith(Reactions reactions, String value, int me) =>
    reactions[value]?.any((user) => user.id == me) ?? false;
