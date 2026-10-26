import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/project_sharing_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';

final _log = Logger('AccountData');

const _linkShareMissing = 3006;

final class OnlineProjectSharingRepository implements ProjectSharingRepository {
  new({
    required this._port,
    required this._sync,
    required this._currentUsername,
  });

  final ProjectSharingPort _port;
  final SyncEngine _sync;

  /// Null once signed out.
  final String? Function() _currentUsername;

  @override
  Future<List<ProjectUserShare>> userShares(int projectId) =>
      _port.listUsers(projectId);

  @override
  Future<void> shareWithUser(
    int projectId,
    String username,
    Permission permission,
  ) => _port.addUser(projectId, username, permission);

  @override
  Future<void> setUserPermission(
    int projectId,
    String username,
    Permission permission,
  ) async {
    await _port.setUserPermission(projectId, username, permission);
    if (_isMe(username)) _settle('Changed own share of project $projectId');
  }

  @override
  Future<void> removeUserShare(int projectId, String username) async {
    await _port.removeUser(projectId, username);
    if (_isMe(username)) _settle('Removed own share of project $projectId');
  }

  @override
  Future<List<ProjectTeamShare>> teamShares(int projectId) =>
      _port.listTeams(projectId);

  @override
  Future<void> shareWithTeam(
    int projectId,
    int teamId,
    Permission permission,
  ) => _port.addTeam(projectId, teamId, permission);

  // Whether the user is in the team would cost a request of its own; a
  // quiet sync after every team share change costs about as much.
  @override
  Future<void> setTeamPermission(
    int projectId,
    int teamId,
    Permission permission,
  ) async {
    await _port.setTeamPermission(projectId, teamId, permission);
    _settle('Changed team share $teamId of project $projectId');
  }

  @override
  Future<void> removeTeamShare(int projectId, int teamId) async {
    await _port.removeTeam(projectId, teamId);
    _settle('Removed team share $teamId of project $projectId');
  }

  @override
  Future<List<LinkShare>> linkShares(int projectId) =>
      _port.listLinkShares(projectId);

  @override
  Future<LinkShare> createLinkShare(int projectId, NewLinkShare share) =>
      _port.createLinkShare(projectId, share);

  @override
  Future<void> deleteLinkShare(int projectId, int shareId) async {
    try {
      await _port.deleteLinkShare(projectId, shareId);
    } on NotFound catch (failure) {
      if (failure.code != _linkShareMissing) rethrow;
    }
  }

  bool _isMe(String username) =>
      username.toLowerCase() == _currentUsername()?.toLowerCase();

  /// The stored permission follows with the next run.
  void _settle(String done) {
    _log.fine(done);
    unawaited(
      _sync.refreshAfterWrite().then<void>(
        (_) {},
        onError: (Object error) =>
            _log.fine('Sync after a share change failed: ${error.runtimeType}'),
      ),
    );
  }
}
