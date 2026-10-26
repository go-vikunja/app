import 'package:dio/dio.dart';
import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/dto/team_codec.dart';
import 'package:vikunja_api/src/read/task_query_params.dart';
import 'package:vikunja_api/src/teams/teams_port.dart';
import 'package:vikunja_api/src/transport/all_pages.dart';
import 'package:vikunja_api/src/write/write_transport.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

final class TeamsApi implements TeamsPort {
  new({required Dio dio, required ServerConnection connection})
    : _transport = WriteTransport(dio, connection),
      _perPage = connection.info.maxItemsPerPage;

  final WriteTransport _transport;
  final int _perPage;

  @override
  Future<List<Team>> list({String? query, bool includePublic = false}) async {
    final search = query?.trim() ?? '';
    final teams = await readAllPages(
      _transport,
      '/teams',
      parseTeam,
      idOf: (team) => team.id,
      perPage: _perPage,
      query: {
        if (search.isNotEmpty) searchParameterName(_transport.version): search,
        if (includePublic) 'include_public': 'true',
      },
      pastTotal: includePublic,
    );
    // A team always has a member: servers before 2.6 list some without.
    return List.unmodifiable([
      for (final team in teams)
        if (team.members.isEmpty) await _readOr(team) else team,
    ]);
  }

  Future<Team> _readOr(Team listed) async {
    try {
      return await read(listed.id);
    } on Forbidden {
      return listed;
    }
  }

  @override
  Future<Team> read(int id) async {
    final response = await _transport.send('GET', '/teams/$id');
    final header = Permission.fromValue(
      int.tryParse(response.headers.value('x-max-permission') ?? ''),
    );
    return _transport.decode<Team>(
      response,
      (json) => parseTeam(json, maxPermission: header),
    );
  }

  @override
  Future<Team> create(NewTeam team) async {
    final created = _transport.decode(
      await _transport.send(
        _transport.createMethod,
        '/teams',
        body: encodeNewTeam(team),
      ),
      parseTeam,
    );
    try {
      return await read(created.id);
    } on VikunjaFailure {
      // The team exists: failing here would invite a second create.
      return Team(
        id: created.id,
        name: created.name,
        description: created.description,
        isPublic: created.isPublic,
        isExternal: created.isExternal,
        createdBy: created.createdBy,
        members: [
          if (created.createdBy case final creator?)
            TeamMember(user: creator, admin: true),
        ],
        created: created.created,
        updated: created.updated,
        maxPermission: Permission.admin,
      );
    }
  }

  @override
  Future<Team> update(int id, TeamChanges changes) async {
    final path = '/teams/$id';
    final body = encodeTeamChanges(changes);
    if (body.isEmpty) return await read(id);
    final Response<Object?> response;
    switch (_transport.version) {
      case ApiVersion.v2:
        response = await _transport.patchOrReplace(path, 'team', body);
      case ApiVersion.v1:
        final current = _transport.decode(
          await _transport.send('GET', path),
          (json) => objectOf(json, 'team'),
        );
        response = await _transport.send(
          'POST',
          path,
          body: {
            'name': current['name'],
            'description': current['description'],
            'is_public': current['is_public'] ?? false,
            ...body,
          },
        );
    }
    final updated = _transport.decode(response, parseTeam);
    return updated.members.isEmpty ? await read(id) : updated;
  }

  @override
  Future<void> delete(int id) async {
    await _transport.send('DELETE', '/teams/$id');
  }

  @override
  Future<void> addMember(
    int teamId,
    String username, {
    bool admin = false,
  }) async {
    await _transport.send(
      _transport.createMethod,
      '/teams/$teamId/members',
      body: {'username': username, 'admin': admin},
    );
  }

  @override
  Future<void> removeMember(int teamId, String username) async {
    await _transport.send('DELETE', _memberPath(teamId, username));
  }

  @override
  Future<bool> toggleAdmin(int teamId, String username) async {
    final member = _transport.decode(
      await _transport.send('POST', '${_memberPath(teamId, username)}/admin'),
      (json) => objectOf(json, 'team member'),
    );
    if (intOr(member, 'id', 0) != 0) return member['admin'] == true;
    // An empty membership answers someone outside the team, but a server
    // that does not carry the stored row back into its answer (probably
    // every one before 2.4) answers each toggle with one.
    final team = await read(teamId);
    final wanted = username.toLowerCase();
    for (final member in team.members) {
      if (member.user.username.toLowerCase() == wanted) return member.admin;
    }
    throw const TeamMemberMissing();
  }

  static String _memberPath(int teamId, String username) =>
      '/teams/$teamId/members/${Uri.encodeComponent(username)}';
}
