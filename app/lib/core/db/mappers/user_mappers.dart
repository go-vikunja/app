import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';

UserRow userRow(User user) =>
    UserRow(id: user.id, username: user.username, name: user.name);

/// The email is only ever present on the user's own record and not stored.
User userFromRow(UserRow row) =>
    User(id: row.id, username: row.username, name: row.name);
