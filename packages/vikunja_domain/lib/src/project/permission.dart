/// What a user may do with a project and its tasks: the server's
/// `max_permission` and share `permission` scale.
enum Permission {
  read(0),
  write(1),
  admin(2);

  new(this.value);

  final int value;

  bool get canWrite => value >= write.value;

  bool get isAdmin => this == admin;

  static Permission? fromValue(Object? value) =>
      values.where((permission) => permission.value == value).firstOrNull;
}
