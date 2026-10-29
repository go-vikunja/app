import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/common/presentation/action_failure_text.dart';

/// The controls of the Account settings page; a refusal of the server is
/// shown at the one whose change it refused.
enum AccountSettingsField {
  name,
  defaultProject,
  defaultView,
  quickAddMagic,
  minimumPriority,
  overviewFilter,
  weekStart,
  timezone,
  language,
  dateDisplay,
  timeFormat,
  emailReminders,
  overdueReminders,
  overdueTime,
  discoverableByName,
  discoverableByEmail,
  colorScheme,
}

/// What to show at [field] when the server refused [changes]; null when
/// [error] is not about the value (no connection, a session that ended).
/// The control shows the stored value again, so a refused time zone is
/// named.
String? accountSettingsFieldError(
  AppLocalizations l10n,
  Object error,
  AccountSettingsField field,
  UserSettingsChanges changes,
) => switch (error) {
  VikunjaFailure(code: 1025) => l10n.accountSettingsTimezoneInvalid(
    (changes.timezone ?? '').replaceAll('_', ' '),
  ),
  VikunjaFailure(code: 3017) => l10n.accountSettingsDefaultProjectInvalid,
  ValidationFailed() || VikunjaFailure(code: 2002)
      when field == AccountSettingsField.overdueTime =>
    l10n.accountSettingsOverdueTimeInvalid,
  ValidationFailed() ||
  VikunjaFailure(code: 2002) => l10n.accountSettingsInvalid,
  _ => null,
};

/// A change of the account's settings that failed for another reason
/// than its value.
String accountSettingsFailureText(AppLocalizations l10n, Object error) {
  final shared = actionFailureText(l10n, error);
  return switch (error) {
    // The server may have made the change before the answer was lost.
    NetworkFailure(problem: NetworkProblem.timeout) =>
      l10n.accountSettingsUnconfirmed,
    NetworkFailure() => l10n.accountSettingsNeedsConnection,
    SessionEnded() || TokenRejected() => l10n.accountSettingsSignInAgain,
    _ when shared != null => shared,
    VikunjaFailure(:final message) when message.trim().isNotEmpty =>
      l10n.accountSettingsRefused(message.trim()),
    _ => l10n.accountSettingsFailed,
  };
}

/// An avatar upload the server or this device could not take: the
/// picture itself, else as [accountSettingsFailureText].
String avatarUploadFailureText(AppLocalizations l10n, Object error) =>
    switch (error) {
      FileTooLarge() || VikunjaFailure(code: 4032) => l10n.avatarImageTooLarge,
      ValidationFailed() ||
      UnexpectedResponse(statusCode: 400) => l10n.avatarImageUnusable,
      _ => accountSettingsFailureText(l10n, error),
    };
