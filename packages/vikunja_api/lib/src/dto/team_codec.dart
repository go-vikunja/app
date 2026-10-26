import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/dto/user_codec.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// [maxPermission] is the v1 `x-max-permission` header of a single read;
/// v2 sends `max_permission` in the body.
Team parseTeam(Object? json, {Permission? maxPermission}) {
  final map = objectOf(json, 'team');
  return Team(
    id: requireInt(map, 'id', 'team'),
    name: requireString(map, 'name', 'team'),
    description: stringOr(map, 'description', ''),
    isPublic: boolOr(map, 'is_public', fallback: false),
    isExternal: stringOr(map, 'external_id', '').isNotEmpty,
    createdBy: parseOtherUser(map['created_by']),
    members: [...objectListOf(map['members']).map(_parseMember).nonNulls],
    created: dateOf(map['created']),
    updated: dateOf(map['updated']),
    maxPermission: Permission.fromValue(map['max_permission']) ?? maxPermission,
  );
}

TeamMember? _parseMember(Map<String, Object?> json) =>
    switch (parseOtherUser(json)) {
      final user? => TeamMember(user: user, admin: json['admin'] == true),
      null => null,
    };

/// The create body: never an `external_id`, which 2.7.0 would store.
Map<String, Object?> encodeNewTeam(NewTeam team) => {
  'name': team.name,
  'description': ?team.description,
  'is_public': ?team.isPublic,
};

/// Only the set fields. The server keeps the old description for an empty
/// one, so a cleared description is the web editor's empty paragraph.
Map<String, Object?> encodeTeamChanges(TeamChanges changes) => {
  'name': ?changes.name,
  if (changes.description case final description?)
    'description': description.isEmpty ? emptyTeamDescription : description,
  'is_public': ?changes.isPublic,
};

const emptyTeamDescription = '<p></p>';
