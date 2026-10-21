import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

const _exportLifetime = Duration(days: 7);

/// `{secret, enabled, url}`: reads whether a secret is present, never the
/// secret or the url themselves. Up to 2.6 the server sends both even while
/// TOTP is on.
TotpStatus parseTotpStatus(Object? json) {
  final map = objectOf(json, 'totp');
  if (boolOr(map, 'enabled', fallback: false)) return TotpStatus.enabled;
  return switch (map['secret']) {
    final String secret when secret.isNotEmpty => TotpStatus.setupStarted,
    _ => TotpStatus.notSetUp,
  };
}

/// `{id, device_info, ip_address, created, last_active}`.
UserSession parseUserSession(Object? json) {
  final map = objectOf(json, 'session');
  return UserSession(
    id: requireString(map, 'id', 'session'),
    deviceInfo: stringOr(map, 'device_info', ''),
    ipAddress: stringOr(map, 'ip_address', ''),
    created: dateOf(map['created']),
    lastActive: dateOf(map['last_active']),
  );
}

/// `{id, title, permissions, expires_at, created, owner_id?}`; a create
/// answer adds `token`, which this ignores.
ApiToken parseApiToken(Object? json) {
  final map = objectOf(json, 'token');
  return ApiToken(
    id: requireInt(map, 'id', 'token'),
    title: stringOr(map, 'title', ''),
    permissions: _permissionsOf(map['permissions']),
    expiresAt:
        dateOf(map['expires_at']) ??
        (throw const MalformedJson('token without expires_at')),
    created: dateOf(map['created']),
  );
}

CreatedApiToken parseCreatedApiToken(Object? json) => CreatedApiToken(
  token: parseApiToken(json),
  secret: _secretOf(json, 'token'),
);

Map<String, Object?> encodeNewApiToken(NewApiToken token) => {
  'title': token.title,
  'permissions': {
    for (final MapEntry(:key, :value) in token.permissions.entries) key: value,
  },
  'expires_at': encodeDate(token.expiresAt),
};

/// `GET /routes`: `{group: {permission: {path, method}}}`, v2 with a
/// `$schema` key.
ApiPermissionGroups parseApiPermissionGroups(Object? json) {
  final map = objectOf(json, 'routes');
  return ApiPermissionGroups({
    for (final MapEntry(:key, :value) in map.entries)
      if (value is Map<String, Object?> && !key.startsWith(r'$'))
        key: List.unmodifiable(value.keys),
  });
}

/// `{id, token, created}`; lists send the token empty.
CaldavToken parseCaldavToken(Object? json) {
  final map = objectOf(json, 'caldav token');
  return CaldavToken(
    id: requireInt(map, 'id', 'caldav token'),
    created: dateOf(map['created']),
  );
}

CreatedCaldavToken parseCreatedCaldavToken(Object? json) => CreatedCaldavToken(
  token: parseCaldavToken(json),
  secret: _secretOf(json, 'token'),
);

/// `{id, size, created, expires}`; null for none, which v1 sends as `{}`
/// and v2 as `null`.
UserDataExport? parseUserDataExport(Object? json) {
  if (json == null) return null;
  final map = objectOf(json, 'export');
  final id = intOr(map, 'id', 0);
  if (id <= 0) return null;
  final created = dateOf(map['created']);
  return UserDataExport(
    id: id,
    size: intOr(map, 'size', 0),
    created: created,
    expires:
        dateOf(map['expires']) ??
        created?.add(_exportLifetime) ??
        (throw const MalformedJson('export without expires')),
  );
}

Map<String, List<String>> _permissionsOf(Object? value) => switch (value) {
  final Map<String, Object?> groups => {
    for (final MapEntry(:key, :value) in groups.entries)
      key: stringListOf(value),
  },
  _ => const {},
};

/// The message never quotes the value.
String _secretOf(Object? json, String key) =>
    switch (objectOf(json, 'created token')[key]) {
      final String secret when secret.isNotEmpty => secret,
      _ => throw const MalformedJson('created token without its value'),
    };
