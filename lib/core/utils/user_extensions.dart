import 'package:vikunja_app/domain/entities/user.dart';

extension UserDisplay on User {
  /// Returns the user's display name if available, otherwise their username.
  String get displayName => name.isNotEmpty ? name : username;
}
