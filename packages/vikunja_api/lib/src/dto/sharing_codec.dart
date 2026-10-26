import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/dto/user_codec.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// A user with the permission of their share; `id` is the user's.
ProjectUserShare parseProjectUserShare(Object? json) {
  final map = objectOf(json, 'user share');
  return ProjectUserShare(
    user:
        parseOtherUser(map) ??
        (throw const MalformedJson('user share without a user')),
    permission: _permissionOf(map, 'user share'),
  );
}

/// A team with the permission of its share; a team the reader may not see
/// comes with an empty name and no members.
ProjectTeamShare parseProjectTeamShare(Object? json) {
  final map = objectOf(json, 'team share');
  final name = stringOr(map, 'name', '');
  return ProjectTeamShare(
    teamId: requireInt(map, 'id', 'team share'),
    teamName: name.isEmpty ? null : name,
    memberCount: switch (map['members']) {
      final List<Object?> members => members.length,
      _ => null,
    },
    permission: _permissionOf(map, 'team share'),
  );
}

LinkShare parseLinkShare(Object? json) {
  final map = objectOf(json, 'link share');
  return LinkShare(
    id: requireInt(map, 'id', 'link share'),
    hash: requireString(map, 'hash', 'link share'),
    name: stringOr(map, 'name', ''),
    permission: _permissionOf(map, 'link share'),
    passwordProtected: intOr(map, 'sharing_type', 0) == _withPassword,
    sharedBy: parseOtherUser(map['shared_by']),
    created: dateOf(map['created']),
  );
}

const _withPassword = 2;

/// Only the three fields the server takes: v2 refuses any other.
Map<String, Object?> encodeNewLinkShare(NewLinkShare share) => {
  'permission': share.permission.value,
  if (share.name case final name? when name.isNotEmpty) 'name': name,
  if (share.password case final password? when password.isNotEmpty)
    'password': password,
};

Permission _permissionOf(Map<String, Object?> map, String what) =>
    Permission.fromValue(map['permission']) ??
    (throw MalformedJson('$what without a known permission'));
