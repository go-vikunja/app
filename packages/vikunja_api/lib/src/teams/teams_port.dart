import 'package:dio/dio.dart';
import 'package:vikunja_api/src/teams/teams_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// The signed-in user's teams and their members, on `/api/v2` from 2.4.0
/// and `/api/v1` before. Online only: nothing here is stored. Team writes
/// need team admin (`Forbidden` without a code otherwise, also for a team
/// the user is not in or that does not exist). `external_id` is never sent.
abstract interface class TeamsPort {
  /// The user's teams, every page (v1 `s`, v2 `q` for [query]), with their
  /// members; with [includePublic] also every public team, which the server
  /// ignores while public teams are turned off. A team listed without
  /// members (servers before 2.6) is read on its own.
  Future<List<Team>> list({String? query, bool includePublic = false});

  /// With [Team.maxPermission] (v2 in the body, v1 the `x-max-permission`
  /// header).
  Future<Team> read(int id);

  /// v2 `POST`, v1 `PUT /teams`; the creator becomes its admin. Returns the
  /// team read back, because the answer has no members, or, when that read
  /// fails, the created team with its creator as the only admin. Not
  /// idempotent. A name outside 1 to 250 code points is a
  /// `ValidationFailed` (v1 412 code 2002, v2 422).
  Future<Team> create(NewTeam team);

  /// v2 merge-patch of the set fields; v1 posts name, description and
  /// `is_public` from a fresh read with [changes] overlaid, since a v1
  /// update resets an `is_public` it is not sent. An empty description is
  /// sent as `<p></p>`: the server keeps the old text for an empty one.
  /// Returns the team as stored, without [Team.maxPermission]; empty
  /// changes are a read.
  Future<Team> update(int id, TeamChanges changes);

  /// `DELETE /teams/{id}`: also removes the team's project shares, and the
  /// members who lose access lose their assignments, subscriptions and
  /// webhooks there.
  Future<void> delete(int id);

  /// v2 `POST`, v1 `PUT /teams/{id}/members` with `{username, admin}`.
  /// Someone already in the team is a `DomainError` 409 code 6005, an
  /// unknown username a `NotFound` code 1005 (exact username, any case).
  Future<void> addMember(int teamId, String username, {bool admin = false});

  /// `DELETE /teams/{id}/members/{username}`; with the user's own username
  /// this leaves the team. The last member is a `DomainError` 400 code
  /// 6006, a member of an external team a `DomainError` 412 code 6010, an
  /// unknown username a `NotFound` code 1005. The server removes a
  /// non-member silently (2.7.0) or refuses it (`Forbidden`, 2.7.1).
  Future<void> removeMember(int teamId, String username);

  /// `POST /teams/{id}/members/{username}/admin`: flips the admin flag
  /// (there is no set) and returns the new one. A user who is not in the
  /// team is [TeamMemberMissing]. An answer without the membership's id
  /// (someone outside the team on 2.7.0, every toggle on servers that do
  /// not carry the stored row back) is settled by reading the team.
  Future<bool> toggleAdmin(int teamId, String username);
}

/// Over [dio] and [connection] like `createAccountSecurityPort`.
TeamsPort createTeamsPort({
  required Dio dio,
  required ServerConnection connection,
}) => TeamsApi(dio: dio, connection: connection);
