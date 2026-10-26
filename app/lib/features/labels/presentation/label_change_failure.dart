import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

enum LabelChange { create, edit, delete }

String labelChangeFailureText(
  AppLocalizations l10n,
  Object error,
  LabelChange change,
) {
  final create = change == LabelChange.create;
  return switch (error) {
    // The server may have made the change before the answer was lost.
    NetworkFailure(problem: NetworkProblem.timeout) when create =>
      l10n.labelPickerCreateUnconfirmed,
    NetworkFailure(problem: NetworkProblem.timeout) => l10n.labelsUnconfirmed,
    NetworkFailure() when create => l10n.labelsNewOffline,
    NetworkFailure() => l10n.labelsNeedsConnection,
    Forbidden() when !create => l10n.labelsNotCreator,
    NotFound() when !create => l10n.labelsGone,
    ValidationFailed() || VikunjaFailure(code: 2002) => l10n.labelsInvalid,
    VikunjaFailure(:final message) when message.trim().isNotEmpty =>
      create
          ? l10n.labelPickerCreateRejected(message.trim())
          : l10n.labelsRefused(message.trim()),
    _ when create => l10n.labelPickerCreateFailed,
    _ => l10n.labelsFailed,
  };
}
