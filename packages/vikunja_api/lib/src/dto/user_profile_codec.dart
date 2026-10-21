import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// The profile part of `GET /user`; null when [json] is not a user object
/// with a numeric id and a username.
UserProfile? parseUserProfile(Object? json) {
  if (json case {'id': final int id, 'username': final String username}) {
    final map = objectOf(json, 'user');
    return UserProfile(
      id: id,
      username: username,
      name: stringOr(map, 'name', ''),
      isLocalUser: boolOr(map, 'is_local_user', fallback: true),
      authProvider: stringOr(map, 'auth_provider', ''),
      pendingEmail: switch (map['pending_email']) {
        final String email when email.isNotEmpty => email,
        _ => null,
      },
      updated: dateOf(map['updated']),
    );
  }
  return null;
}
