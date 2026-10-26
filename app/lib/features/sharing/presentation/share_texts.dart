import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

String permissionLabel(AppLocalizations l10n, Permission permission) =>
    switch (permission) {
      Permission.read => l10n.sharePermissionRead,
      Permission.write => l10n.sharePermissionWrite,
      Permission.admin => l10n.sharePermissionAdmin,
    };

enum ShareChange {
  addPerson,
  changePerson,
  removePerson,
  addTeam,
  changeTeam,
  removeTeam,
  createLink,
  deleteLink;

  bool get concernsLinks => this == createLink || this == deleteLink;
}

String shareFailureText(
  AppLocalizations l10n,
  Object error,
  ShareChange change,
) => switch (error) {
  // The server may have made the change before the answer was lost.
  NetworkFailure(problem: NetworkProblem.timeout) =>
    l10n.shareFailureUnconfirmed,
  NetworkFailure() => l10n.shareFailureOffline,
  // Without link sharing the server has no such routes.
  NotFound(routeAbsent: true) when change.concernsLinks =>
    l10n.shareFailureLinkSharingOff,
  VikunjaFailure(code: 7002) => l10n.shareFailureAlreadyShared,
  VikunjaFailure(code: 1005) => l10n.shareFailureUnknownUser,
  VikunjaFailure(code: 7003 || 6007 || 3006) => l10n.shareFailureGone,
  VikunjaFailure(code: 6004) => l10n.shareFailureTeamAlreadyShared,
  VikunjaFailure(code: 6002) => l10n.shareFailureUnknownTeam,
  NotFound(code: 3001) => l10n.projectGone,
  Forbidden() => l10n.shareFailureForbidden,
  ValidationFailed() ||
  VikunjaFailure(code: 2002 || 2004) => l10n.shareFailureInvalid,
  _ => l10n.shareFailureGeneric,
};

/// Whether the share list on screen is out of date after [error]: a share
/// that is gone, or rights that changed meanwhile.
bool shareListOutdatedBy(Object error) => switch (error) {
  Forbidden() || NotFound() => true,
  VikunjaFailure(code: 7002 || 6004) => true,
  _ => false,
};

/// What removing access means: [loss] (who loses access to what), and on
/// servers that do it ([listsCleanup], 2.7.0 and later) what the server
/// deletes in the projects they can no longer reach, as the web's dialog
/// lists it.
String accessRemovalBody(
  AppLocalizations l10n, {
  required String loss,
  required bool self,
  required bool listsCleanup,
}) {
  if (!listsCleanup) return loss;
  final (intro, items) = self
      ? (
          l10n.shareCleanupSelfIntro,
          [
            l10n.shareCleanupSelfAssignments,
            l10n.shareCleanupSelfSubscriptions,
            l10n.shareCleanupSelfWebhooks,
          ],
        )
      : (
          l10n.shareCleanupOthersIntro,
          [
            l10n.shareCleanupOthersAssignments,
            l10n.shareCleanupOthersSubscriptions,
            l10n.shareCleanupOthersWebhooks,
          ],
        );
  return [loss, '', intro, for (final item in items) '• $item'].join('\n');
}
