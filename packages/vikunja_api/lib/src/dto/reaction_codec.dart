import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/dto/user_codec.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// A reaction map, `{value: [user, …]}` in the server's key order; `null`
/// or `{}` when nobody reacted. A value without a readable user is left
/// out.
Reactions parseReactions(Object? json) {
  if (json is! Map<String, Object?>) return const {};
  final reactions = <String, List<User>>{};
  for (final MapEntry(key: value, value: users) in json.entries) {
    final parsed = objectListOf(users).map(parseUser).nonNulls.toList();
    if (parsed.isNotEmpty) reactions[value] = List.unmodifiable(parsed);
  }
  return Map.unmodifiable(reactions);
}
