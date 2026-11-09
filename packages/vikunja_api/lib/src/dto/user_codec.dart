import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// Null when [json] is not a user object with a numeric id and a username.
User? parseUser(Object? json) {
  if (json case {'id': final int id, 'username': final String username}) {
    final map = objectOf(json, 'user');
    return User(
      id: id,
      username: username,
      name: stringOr(map, 'name', ''),
      email: switch (map['email']) {
        final String email when email.isNotEmpty => email,
        _ => null,
      },
    );
  }
  return null;
}

/// Someone else as a list names them: never with an email, which servers
/// before 2.8.0 sent with a link share's creator.
User? parseOtherUser(Object? json) => switch (parseUser(json)) {
  final user? => User(id: user.id, username: user.username, name: user.name),
  null => null,
};
