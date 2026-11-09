import 'package:vikunja_mobile/app/l10n/l10n.dart';

/// "The web asks for your password." and, on servers where ten wrong
/// passwords lock the account (`Capability.accountLockout`), that warning.
String webAsksPasswordNote(
  AppLocalizations l10n, {
  required bool accountLockout,
}) => withAccountLockout(
  l10n,
  l10n.accountSettingsWebAsksPassword,
  accountLockout: accountLockout,
);

/// [note] about a page of the web that asks for the password, followed by
/// the warning that ten wrong passwords lock the account where they do
/// (`Capability.accountLockout`).
String withAccountLockout(
  AppLocalizations l10n,
  String note, {
  required bool accountLockout,
}) => [note, if (accountLockout) l10n.accountSettingsAccountLockout].join(' ');
