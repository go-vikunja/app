import 'package:meta/meta.dart';

@immutable
final class User {
  const new({
    required this.id,
    required this.username,
    this.name = '',
    this.email,
  });

  final int id;
  final String username;
  final String name;

  /// Only present on the user's own record.
  final String? email;

  String get displayName => name.trim().isEmpty ? username : name.trim();

  @override
  bool operator ==(Object other) =>
      other is User &&
      other.id == id &&
      other.username == username &&
      other.name == name &&
      other.email == email;

  @override
  int get hashCode => Object.hash(id, username, name, email);

  @override
  String toString() => 'User($id, $username)';
}
