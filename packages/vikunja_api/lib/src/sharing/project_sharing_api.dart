import 'package:dio/dio.dart';
import 'package:vikunja_api/src/dto/sharing_codec.dart';
import 'package:vikunja_api/src/sharing/project_sharing_port.dart';
import 'package:vikunja_api/src/transport/all_pages.dart';
import 'package:vikunja_api/src/write/write_transport.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

final class ProjectSharingApi implements ProjectSharingPort {
  new({required Dio dio, required ServerConnection connection})
    : _transport = WriteTransport(dio, connection),
      _perPage = connection.info.maxItemsPerPage;

  final WriteTransport _transport;
  final int _perPage;

  @override
  Future<List<ProjectUserShare>> listUsers(int projectId) => readAllPages(
    _transport,
    '/projects/$projectId/users',
    parseProjectUserShare,
    idOf: (share) => share.user.id,
    perPage: _perPage,
  );

  @override
  Future<void> addUser(
    int projectId,
    String username,
    Permission permission,
  ) async {
    await _transport.send(
      _transport.createMethod,
      '/projects/$projectId/users',
      body: {'username': username, 'permission': permission.value},
    );
  }

  @override
  Future<void> setUserPermission(
    int projectId,
    String username,
    Permission permission,
  ) async {
    await _transport.send(
      _transport.updateMethod,
      _userPath(projectId, username),
      body: {'permission': permission.value},
    );
  }

  @override
  Future<void> removeUser(int projectId, String username) async {
    await _transport.send('DELETE', _userPath(projectId, username));
  }

  @override
  Future<List<ProjectTeamShare>> listTeams(int projectId) => readAllPages(
    _transport,
    '/projects/$projectId/teams',
    parseProjectTeamShare,
    idOf: (share) => share.teamId,
    perPage: _perPage,
  );

  @override
  Future<void> addTeam(int projectId, int teamId, Permission permission) async {
    await _transport.send(
      _transport.createMethod,
      '/projects/$projectId/teams',
      body: {'team_id': teamId, 'permission': permission.value},
    );
  }

  @override
  Future<void> setTeamPermission(
    int projectId,
    int teamId,
    Permission permission,
  ) async {
    await _transport.send(
      _transport.updateMethod,
      '/projects/$projectId/teams/$teamId',
      body: {'permission': permission.value},
    );
  }

  @override
  Future<void> removeTeam(int projectId, int teamId) async {
    await _transport.send('DELETE', '/projects/$projectId/teams/$teamId');
  }

  @override
  Future<List<LinkShare>> listLinkShares(int projectId) => readAllPages(
    _transport,
    '/projects/$projectId/shares',
    parseLinkShare,
    idOf: (share) => share.id,
    perPage: _perPage,
  );

  @override
  Future<LinkShare> createLinkShare(int projectId, NewLinkShare share) async =>
      _transport.decode<LinkShare>(
        await _transport.send(
          _transport.createMethod,
          '/projects/$projectId/shares',
          body: encodeNewLinkShare(share),
        ),
        parseLinkShare,
      );

  @override
  Future<void> deleteLinkShare(int projectId, int shareId) async {
    await _transport.send('DELETE', '/projects/$projectId/shares/$shareId');
  }

  static String _userPath(int projectId, String username) =>
      '/projects/$projectId/users/${Uri.encodeComponent(username)}';
}
