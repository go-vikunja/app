import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

/// Why a change of a saved filter did not go through. [fromForm]: a
/// timeout there may still have saved it, so the form says to check first;
/// the list's menu can be pulled down instead.
String savedFilterFailureText(
  AppLocalizations l10n,
  Object error, {
  required bool fromForm,
}) => switch (error) {
  NetworkFailure(problem: NetworkProblem.timeout) when fromForm =>
    l10n.projectFormUnconfirmed,
  NetworkFailure(problem: NetworkProblem.timeout) =>
    l10n.projectChangeUnconfirmed,
  NetworkFailure() => l10n.savedFilterChangeNeedsConnection,
  Forbidden() => l10n.savedFilterChangeForbidden,
  VikunjaFailure(code: 4024 || 4019 || 4016, :final message) =>
    l10n.projectViewFilterInvalid(message.trim()),
  NotFound() => l10n.savedFilterGone,
  ValidationFailed() ||
  VikunjaFailure(code: 2002) => l10n.savedFilterChangeInvalid,
  VikunjaFailure(:final message) when message.trim().isNotEmpty =>
    l10n.projectChangeRefused(message.trim()),
  _ => l10n.projectChangeFailed,
};

/// Whether [error] is the server refusing the filter text, which the form
/// shows at the filter field.
bool isInvalidSavedFilter(Object error) =>
    error is VikunjaFailure && const {4024, 4019, 4016}.contains(error.code);
