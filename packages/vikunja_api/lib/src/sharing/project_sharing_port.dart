import 'package:dio/dio.dart';
import 'package:vikunja_api/src/sharing/project_sharing_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// Who may reach a project: shares with users, with teams and links, on
/// `/api/v2` from 2.4.0 and `/api/v1` before. Online only. Lists need read
/// access (link shares admin); every change needs project admin
/// (`Forbidden` without a code otherwise). The change answers are not
/// rows (`id` 0, no `created`), so callers read the list again. Shares
/// work on archived projects too. Removing a share removes, for everyone
/// who loses access, their assignments, subscriptions and webhooks there.
abstract interface class ProjectSharingPort {
  /// Every page; neither the owner nor team members are listed.
  Future<List<ProjectUserShare>> listUsers(int projectId);

  /// v2 `POST`, v1 `PUT /projects/{p}/users`. [username] must be the exact
  /// one (take it from a user search). Already shared, or the owner, is a
  /// `DomainError` 409 code 7002; an unknown username a `NotFound` code
  /// 1005.
  Future<void> addUser(int projectId, String username, Permission permission);

  /// v2 `PUT`, v1 `POST /projects/{p}/users/{username}`. The server answers
  /// a user without a share with success and creates nothing.
  Future<void> setUserPermission(
    int projectId,
    String username,
    Permission permission,
  );

  /// `DELETE /projects/{p}/users/{username}`. A user without a share is a
  /// `Forbidden` code 7003, an unknown username a `NotFound` code 1005.
  Future<void> removeUser(int projectId, String username);

  /// Every page. A team the reader may not see comes without its name
  /// ([ProjectTeamShare.isHidden]); it can still be changed or removed.
  Future<List<ProjectTeamShare>> listTeams(int projectId);

  /// v2 `POST`, v1 `PUT /projects/{p}/teams` with `{team_id, permission}`.
  /// The user must be in the team (or it is public with public teams on),
  /// else `Forbidden`. Already shared is a `DomainError` 409 code 6004, an
  /// unknown team a `NotFound` code 6002.
  Future<void> addTeam(int projectId, int teamId, Permission permission);

  /// v2 `PUT`, v1 `POST /projects/{p}/teams/{team}`.
  Future<void> setTeamPermission(
    int projectId,
    int teamId,
    Permission permission,
  );

  /// `DELETE /projects/{p}/teams/{team}`. A team without a share is a
  /// `Forbidden` code 6007, an unknown team a `NotFound` code 6002.
  Future<void> removeTeam(int projectId, int teamId);

  /// Every page. A server with link sharing turned off has no such route:
  /// `NotFound` with `routeAbsent`, for every link share call.
  Future<List<LinkShare>> listLinkShares(int projectId);

  /// v2 `POST`, v1 `PUT /projects/{p}/shares`; returns the new share with
  /// its hash. Not idempotent.
  Future<LinkShare> createLinkShare(int projectId, NewLinkShare share);

  /// `DELETE /projects/{p}/shares/{id}`; one that is gone is a `NotFound`
  /// code 3006. Link shares cannot be changed.
  Future<void> deleteLinkShare(int projectId, int shareId);
}

/// Over [dio] and [connection] like `createAccountSecurityPort`.
ProjectSharingPort createProjectSharingPort({
  required Dio dio,
  required ServerConnection connection,
}) => ProjectSharingApi(dio: dio, connection: connection);
