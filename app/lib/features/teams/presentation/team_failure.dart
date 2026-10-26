import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

enum TeamChange {
  create,
  edit,
  addMember,
  toggleAdmin,
  removeMember,
  leave,
  delete,
}

String teamFailureText(
  AppLocalizations l10n,
  Object error,
  TeamChange change,
) => switch (error) {
  // The server may have made the change before the answer was lost.
  NetworkFailure(problem: NetworkProblem.timeout) => l10n.teamUnconfirmed,
  NetworkFailure() when change == TeamChange.create => l10n.teamsNewOffline,
  NetworkFailure() when change == TeamChange.addMember =>
    l10n.teamAddMemberOffline,
  NetworkFailure() => l10n.teamNeedsConnection,
  TeamMemberMissing() => l10n.teamNotMember,
  VikunjaFailure(code: 6005) => l10n.teamAlreadyMember,
  VikunjaFailure(code: 6006) => l10n.teamLastMemberRefused,
  VikunjaFailure(code: 6010) => l10n.teamExternalRefused,
  VikunjaFailure(code: 1005) => l10n.teamUnknownUser,
  VikunjaFailure(code: 6002) => l10n.teamGone,
  // From 2.7.1 a member who is no longer in the team is refused leaving.
  Forbidden() when change == TeamChange.leave => l10n.teamGone,
  Forbidden() => l10n.teamForbidden,
  NotFound() => l10n.teamGone,
  ValidationFailed() || VikunjaFailure(code: 2002) => l10n.teamInvalid,
  VikunjaFailure(:final message) when message.trim().isNotEmpty =>
    l10n.teamRefused(message.trim()),
  _ => l10n.teamFailed,
};
