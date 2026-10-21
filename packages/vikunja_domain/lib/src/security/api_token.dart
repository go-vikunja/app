import 'package:meta/meta.dart';

/// An API token as the list answers it: never with its value.
@immutable
final class ApiToken {
  new({
    required this.id,
    required this.title,
    required Map<String, List<String>> permissions,
    required this.expiresAt,
    this.created,
  }) : permissions = _frozen(permissions);

  final int id;
  final String title;

  /// Group to permission names, in the server's order.
  final Map<String, List<String>> permissions;

  /// The server accepts past dates; such a token is dead at once.
  final DateTime expiresAt;
  final DateTime? created;

  int get permissionCount =>
      permissions.values.fold(0, (sum, names) => sum + names.length);

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);

  @override
  bool operator ==(Object other) =>
      other is ApiToken &&
      other.id == id &&
      other.title == title &&
      _samePermissions(other.permissions, permissions) &&
      other.expiresAt == expiresAt &&
      other.created == created;

  @override
  int get hashCode =>
      Object.hash(id, title, _permissionsHash(permissions), expiresAt, created);

  @override
  String toString() => 'ApiToken($id)';
}

/// What the app sends to create an API token.
@immutable
final class NewApiToken {
  new({
    required this.title,
    required Map<String, List<String>> permissions,
    required this.expiresAt,
  }) : permissions = _frozen(permissions);

  /// Not trimmed by the server.
  final String title;

  /// At least one permission, each one from `GET /routes`.
  final Map<String, List<String>> permissions;

  /// Sent as RFC 3339 UTC. The server accepts past dates, so callers refuse
  /// them.
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      other is NewApiToken &&
      other.title == title &&
      _samePermissions(other.permissions, permissions) &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode =>
      Object.hash(title, _permissionsHash(permissions), expiresAt);

  /// Without the title, which is user text.
  @override
  String toString() => 'NewApiToken(expires: $expiresAt)';
}

/// The create answer, the only one that carries the token's value.
final class CreatedApiToken {
  const new({required this.token, required this.secret});

  final ApiToken token;

  /// `tk_` and 40 hex digits; shown once, never stored or logged.
  final String secret;

  @override
  String toString() => 'CreatedApiToken(${token.id}, [redacted])';
}

/// The permissions a server offers to API tokens, from `GET /routes`. The
/// list depends on the server: licences, plugins and migrators change it.
@immutable
final class ApiPermissionGroups {
  new(Map<String, List<String>> groups) : groups = _frozen(groups);

  static const otherGroup = 'other';

  /// Group to permission names, in the server's order.
  final Map<String, List<String>> groups;

  /// The server's order with [otherGroup] last, as the web shows them.
  List<String> get groupNames => List.unmodifiable([
    for (final name in groups.keys)
      if (name != otherGroup) name,
    if (groups.containsKey(otherGroup)) otherGroup,
  ]);

  int get permissionCount =>
      groups.values.fold(0, (sum, names) => sum + names.length);

  bool get isEmpty => permissionCount == 0;

  bool offers(String group, String permission) =>
      groups[group]?.contains(permission) ?? false;

  @override
  bool operator ==(Object other) =>
      other is ApiPermissionGroups && _samePermissions(other.groups, groups);

  @override
  int get hashCode => _permissionsHash(groups);

  @override
  String toString() =>
      'ApiPermissionGroups(${groups.length} groups, $permissionCount)';
}

Map<String, List<String>> _frozen(Map<String, List<String>> permissions) =>
    Map.unmodifiable({
      for (final MapEntry(:key, :value) in permissions.entries)
        key: List<String>.unmodifiable(value),
    });

bool _samePermissions(
  Map<String, List<String>> a,
  Map<String, List<String>> b,
) {
  if (a.length != b.length) return false;
  final aKeys = a.keys.toList();
  final bKeys = b.keys.toList();
  for (var i = 0; i < aKeys.length; i++) {
    if (aKeys[i] != bKeys[i]) return false;
    final aNames = a[aKeys[i]]!;
    final bNames = b[bKeys[i]]!;
    if (aNames.length != bNames.length) return false;
    for (var j = 0; j < aNames.length; j++) {
      if (aNames[j] != bNames[j]) return false;
    }
  }
  return true;
}

int _permissionsHash(Map<String, List<String>> permissions) => Object.hashAll([
  for (final MapEntry(:key, :value) in permissions.entries) ...[
    key,
    Object.hashAll(value),
  ],
]);
