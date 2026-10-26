import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/repositories/team_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';

final _log = Logger('AccountData');

typedef CurrentTeamUser = ({int id, String username});

final class OnlineTeamRepository implements TeamRepository {
  new({required this._port, required this._sync, required this._currentUser});

  final TeamsPort _port;
  final SyncEngine _sync;

  /// Null once signed out.
  final CurrentTeamUser? Function() _currentUser;

  @override
  Future<List<Team>> list({String? query, bool includePublic = false}) =>
      _port.list(query: query, includePublic: includePublic);

  @override
  Future<Team> read(int id) => _port.read(id);

  @override
  Future<Team> create(NewTeam team) async {
    if (teamNameProblem(team.name) != null) {
      throw ArgumentError.value(team, 'team', 'has no valid name');
    }
    return await _port.create(team);
  }

  @override
  Future<Team> update(int id, TeamChanges changes) async {
    if (changes.name case final name? when teamNameProblem(name) != null) {
      throw ArgumentError.value(changes, 'changes', 'has no valid name');
    }
    return await _port.update(id, changes);
  }

  @override
  Future<void> delete(int id) async {
    await _port.delete(id);
    _settle('Deleted team $id');
  }

  @override
  Future<void> addMember(int teamId, String username, {bool admin = false}) =>
      _port.addMember(teamId, username, admin: admin);

  @override
  Future<void> removeMember(int teamId, String username) async {
    _refuseOwn(username);
    await _port.removeMember(teamId, username);
  }

  @override
  Future<bool> toggleAdmin(int teamId, String username) async {
    _refuseOwn(username);
    return await _port.toggleAdmin(teamId, username);
  }

  @override
  Future<void> leave(int teamId) async {
    final me = _me();
    final team = await _port.read(teamId);
    final rule = TeamGuards.of(team, currentUserId: me.id).leave;
    if (rule != TeamLeaveRule.allowed) {
      throw ArgumentError.value(teamId, 'teamId', 'cannot be left: $rule');
    }
    await _port.removeMember(teamId, me.username);
    _settle('Left team $teamId');
  }

  CurrentTeamUser _me() =>
      _currentUser() ??
      (throw const SessionEnded(SessionEndReason.invalidRefreshToken));

  void _refuseOwn(String username) {
    if (username.toLowerCase() == _me().username.toLowerCase()) {
      throw ArgumentError('is the current user', 'username');
    }
  }

  /// The projects the team gave access to go with the next run.
  void _settle(String done) {
    _log.fine(done);
    unawaited(
      _sync.refreshAfterWrite().then<void>(
        (_) {},
        onError: (Object error) =>
            _log.fine('Sync after a team change failed: ${error.runtimeType}'),
      ),
    );
  }
}
