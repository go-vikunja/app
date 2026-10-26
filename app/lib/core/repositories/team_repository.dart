import 'package:vikunja_domain/vikunja_domain.dart';

/// The account's teams on the server. Online only and never stored: every
/// call goes to the server and throws its `VikunjaFailure` (offline a
/// `NetworkFailure`). Checks the server lacks are `ArgumentError`s before
/// any request.
abstract interface class TeamRepository {
  /// The teams the user is in, every page, matching [query] by name when
  /// given; [includePublic] adds the public teams while the server has them
  /// turned on (it ignores the flag otherwise).
  Future<List<Team>> list({String? query, bool includePublic = false});

  /// With [Team.maxPermission]. A team the user is not in (or that does not
  /// exist) is a `Forbidden`.
  Future<Team> read(int id);

  /// The new team with its members: the user, as its admin. A blank name or
  /// one past `Team.maxNameLength` code points is an `ArgumentError`.
  Future<Team> create(NewTeam team);

  /// Team admins only (`Forbidden`). A blank or too long name is an
  /// `ArgumentError`. Returns the team as stored.
  Future<Team> update(int id, TeamChanges changes);

  /// Team admins only. The user loses what the team gave them, so a quiet
  /// sync follows.
  Future<void> delete(int id);

  /// Team admins only. An unknown username is a `NotFound` code 1005, a
  /// member already in the team a `DomainError` code 6005.
  Future<void> addMember(int teamId, String username, {bool admin = false});

  /// Team admins only; never the user's own membership, which is [leave]
  /// (an `ArgumentError`). An external team's members cannot be removed
  /// (`DomainError` code 6010).
  Future<void> removeMember(int teamId, String username);

  /// Makes a member admin or an admin a plain member, and returns whether
  /// they are admin now. Never the user's own (an `ArgumentError`): the
  /// server would let the only admin demote themselves. One who is not in
  /// the team is a [TeamMemberMissing].
  Future<bool> toggleAdmin(int teamId, String username);

  /// Takes the user out of the team, read again first: refused with an
  /// `ArgumentError` unless `TeamGuards.leave` allows it, so that the only
  /// admin never leaves others behind with a team nobody can change. The
  /// user loses what the team gave them, so a quiet sync follows.
  Future<void> leave(int teamId);
}
