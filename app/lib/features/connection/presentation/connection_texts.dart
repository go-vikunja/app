import 'package:intl/intl.dart' as intl;
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/network/network_profile.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';

String formatConnectionDate(AppLocalizations l10n, DateTime date) =>
    intl.DateFormat.yMMMd(l10n.localeName).format(date.toLocal());

/// What is stored for a server, e.g. "Trusted certificate, Access
/// headers"; null when nothing is.
String? connectionSummary(AppLocalizations l10n, NetworkProfile? profile) {
  if (profile == null || profile.isEmpty) return null;
  return [
    if (profile.pin != null) l10n.connectionSummaryPinned,
    if (profile.caCertificate != null) l10n.connectionSummaryCa,
    if (profile.clientCertificate != null)
      l10n.connectionSummaryClientCertificate,
    if (profile.hasHeaders) l10n.connectionSummaryHeaders,
    if (profile.hasCleartextConsent) l10n.connectionSummaryCleartext,
  ].join(', ');
}

/// The Account tab's subtitle of the Connection entry: what needs the
/// user, else what is stored.
String? connectionStatusText(
  AppLocalizations l10n,
  ConnectionProfileState state,
) => switch (state.status) {
  ConnectionProfileStatus.ok => connectionSummary(l10n, state.profile),
  ConnectionProfileStatus.pinMismatch => l10n.connectionStatusPinMismatch,
  ConnectionProfileStatus.needsReentry => l10n.connectionStatusNeedsReentry,
  ConnectionProfileStatus.unavailable => l10n.connectionStatusUnavailable,
  ConnectionProfileStatus.damaged => l10n.connectionStatusDamaged,
};
