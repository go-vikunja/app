import 'package:vikunja_domain/vikunja_domain.dart';

/// Who a project is shared with, on the server. Online only and never
/// stored: every call goes to the server and throws its `VikunjaFailure`
/// (offline a `NetworkFailure`). Reading the user and team shares needs
/// read access; everything else, the link shares included, project admin
/// rights (`Forbidden`). A server with link sharing turned off has no link
/// share routes: those calls are a codeless `NotFound`.
///
/// A change that may lower or end the user's own access (to their own
/// share, or to a team's share) is followed by a quiet sync, so the stored
/// permission follows.
abstract interface class ProjectSharingRepository {
  /// Every page; the owner and team members are not listed.
  Future<List<ProjectUserShare>> userShares(int projectId);

  /// Share with [username] exactly as the server spells it (from a search):
  /// the server matches it with case. Already shared, or the owner, is a
  /// `DomainError` code 7002; an unknown user a `NotFound` code 1005.
  Future<void> shareWithUser(
    int projectId,
    String username,
    Permission permission,
  );

  Future<void> setUserPermission(
    int projectId,
    String username,
    Permission permission,
  );

  /// One without a share is a `Forbidden` code 7003.
  Future<void> removeUserShare(int projectId, String username);

  /// Every page. A team the user cannot see comes without its name.
  Future<List<ProjectTeamShare>> teamShares(int projectId);

  /// Only teams the user is in, or public ones while the server has them
  /// turned on (`Forbidden` otherwise). Already shared is a `DomainError`
  /// code 6004, an unknown team a `NotFound` code 6002.
  Future<void> shareWithTeam(int projectId, int teamId, Permission permission);

  Future<void> setTeamPermission(
    int projectId,
    int teamId,
    Permission permission,
  );

  /// One without a share is a `Forbidden` code 6007.
  Future<void> removeTeamShare(int projectId, int teamId);

  /// Every page. Each carries its secret hash: show it only inside the
  /// link's URL.
  Future<List<LinkShare>> linkShares(int projectId);

  /// A link cannot be changed later, only deleted.
  Future<LinkShare> createLinkShare(int projectId, NewLinkShare share);

  /// Anyone using the link loses access at once. One that is gone already
  /// counts as deleted.
  Future<void> deleteLinkShare(int projectId, int shareId);
}
