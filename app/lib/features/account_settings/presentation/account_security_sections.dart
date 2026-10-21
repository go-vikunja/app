import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/account_settings/application/totp_status_reading.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_deletion.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';

/// Why the two-factor status is not known.
enum TotpProblem {
  /// The server has two-factor authentication off; its route is absent.
  notOffered,

  /// The server says the account belongs to a sign-in provider.
  notLocal,
  failed,
}

/// What the Account settings page shows of the account's security and
/// integrations, each part read on its own when the page opens and on
/// resume; a part that could not be read stays null.
@immutable
final class SecurityOverview {
  const new({
    this.totp,
    this.totpProblem,
    this.sessionCount,
    this.apiTokenCount,
    this.export,
    this.exportRead = false,
  });

  final TotpStatus? totp;
  final TotpProblem? totpProblem;
  final int? sessionCount;
  final int? apiTokenCount;
  final UserDataExport? export;

  /// Whether [export] was read; null then means there is none.
  final bool exportRead;

  SecurityOverview withTotp(TotpStatus? totp, [TotpProblem? problem]) =>
      SecurityOverview(
        totp: totp,
        totpProblem: problem,
        sessionCount: sessionCount,
        apiTokenCount: apiTokenCount,
        export: export,
        exportRead: exportRead,
      );

  SecurityOverview withSessionCount(int count) => SecurityOverview(
    totp: totp,
    totpProblem: totpProblem,
    sessionCount: count,
    apiTokenCount: apiTokenCount,
    export: export,
    exportRead: exportRead,
  );

  SecurityOverview withApiTokenCount(int count) => SecurityOverview(
    totp: totp,
    totpProblem: totpProblem,
    sessionCount: sessionCount,
    apiTokenCount: count,
    export: export,
    exportRead: exportRead,
  );

  SecurityOverview withExport(UserDataExport? export) => SecurityOverview(
    totp: totp,
    totpProblem: totpProblem,
    sessionCount: sessionCount,
    apiTokenCount: apiTokenCount,
    export: export,
    exportRead: true,
  );

  static TotpProblem problemOf(Object error) => switch (error) {
    NotFound(routeAbsent: true) => TotpProblem.notOffered,
    VikunjaFailure(code: 1021) => TotpProblem.notLocal,
    _ => TotpProblem.failed,
  };
}

/// Whether the page offers two-factor authentication: the server has it on
/// and the account signs in with a password, as on the web.
bool offersTotp(ServerConnection connection, UserProfile? profile) =>
    connection.capabilities.has(Capability.totp) &&
    (profile?.isLocalUser ?? false);

/// Two-factor authentication and the sessions, after Password and email.
List<Widget> securitySection({
  required AppLocalizations l10n,
  required ServerConnection connection,
  required UserProfile? profile,
  required SecurityOverview overview,
  required VoidCallback onOpenTotp,
  required VoidCallback onOpenSessions,
}) {
  final totp = overview.totp;
  final problem = overview.totpProblem;
  final unavailable = switch ((totp, problem)) {
    (null, TotpProblem.notOffered || TotpProblem.notLocal) => true,
    _ => false,
  };
  return [
    ListSectionHeader(title: l10n.accountSettingsSecurity),
    if (offersTotp(connection, profile))
      SettingChoiceTile(
        leading: const Icon(Icons.verified_user_outlined),
        title: l10n.accountSettingsTotp,
        value: switch ((totp, problem)) {
          _ when !canReadTotpStatus(connection) =>
            l10n.accountSettingsTotpNotChecked,
          (TotpStatus.enabled, _) => l10n.accountSettingsTotpOn,
          (TotpStatus.notSetUp, _) => l10n.accountSettingsTotpOff,
          (TotpStatus.setupStarted, _) => l10n.accountSettingsTotpSetupStarted,
          (_, TotpProblem.notOffered) => l10n.accountSettingsTotpNotOffered,
          (_, TotpProblem.notLocal) => l10n.accountSettingsTotpNotAvailable,
          (_, TotpProblem.failed) => l10n.accountSettingsTotpUnknown,
          (null, null) => l10n.accountSettingsTotpChecking,
        },
        help: switch (totp) {
          _ when unavailable => null,
          TotpStatus.enabled => l10n.accountSettingsTotpOnNote,
          _ => l10n.accountSettingsTotpTurnOnNote,
        },
        trailing: unavailable ? null : const Icon(Icons.open_in_new),
        onTap: unavailable ? null : onOpenTotp,
      ),
    ListTile(
      leading: const Icon(Icons.devices_outlined),
      title: Text(l10n.accountSettingsSessions),
      subtitle: Text(switch (overview.sessionCount) {
        final count? => l10n.accountSettingsSessionsCount(count),
        null => l10n.accountSettingsSessionsHint,
      }),
      trailing: const Icon(Icons.chevron_right),
      onTap: onOpenSessions,
    ),
  ];
}

/// API tokens and CalDAV, after Appearance.
List<Widget> integrationsSection({
  required AppLocalizations l10n,
  required ServerConnection connection,
  required SecurityOverview overview,
  required VoidCallback onOpenApiTokens,
  required VoidCallback onOpenCaldav,
}) => [
  ListSectionHeader(title: l10n.accountSettingsIntegrations),
  ListTile(
    leading: const Icon(Icons.key_outlined),
    title: Text(l10n.accountSettingsApiTokens),
    subtitle: Text(switch (overview.apiTokenCount) {
      final count? => l10n.accountSettingsApiTokensCount(count),
      null => l10n.accountSettingsApiTokensHint,
    }),
    trailing: const Icon(Icons.chevron_right),
    onTap: onOpenApiTokens,
  ),
  if (connection.capabilities.has(Capability.caldav))
    ListTile(
      leading: const Icon(Icons.calendar_month_outlined),
      title: Text(l10n.accountSettingsCaldav),
      subtitle: Text(l10n.accountSettingsCaldavHint),
      trailing: const Icon(Icons.chevron_right),
      onTap: onOpenCaldav,
    ),
];

/// The data export with its status.
List<Widget> yourDataSection({
  required AppLocalizations l10n,
  required MomentFormatter formatter,
  required SecurityOverview overview,
  required DateTime now,
  required VoidCallback onOpenExport,
}) {
  final export = overview.export;
  return [
    ListSectionHeader(title: l10n.accountSettingsYourData),
    ListTile(
      leading: const Icon(Icons.download_outlined),
      title: Text(l10n.accountSettingsExport),
      subtitle: Text(switch ((overview.exportRead, export)) {
        (true, final export?) when !export.isExpiredAt(now) =>
          l10n.accountSettingsExportReady(formatter.absolute(export.expires)),
        (true, _) => l10n.accountSettingsExportNone,
        (false, _) => l10n.accountSettingsExportHint,
      }),
      trailing: const Icon(Icons.chevron_right),
      onTap: onOpenExport,
    ),
  ];
}

/// Deleting the account, last and in the error colour, where the server
/// allows it; once scheduled, the row names the date.
List<Widget> deleteAccountSection({
  required AppLocalizations l10n,
  required ThemeData theme,
  required MomentFormatter formatter,
  required ServerConnection connection,
  required UserProfile? profile,
  required DateTime now,
  required VoidCallback onDelete,
}) {
  final scheduled = profile?.deletionScheduledAt;
  // v2 ignores the server's switch, so the app must respect it.
  if (!connection.capabilities.has(Capability.userDeletion) &&
      scheduled == null) {
    return const [];
  }
  final error = theme.colorScheme.error;
  return [
    const SizedBox(height: 16),
    const Divider(),
    ListTile(
      leading: Icon(Icons.person_remove_outlined, color: error),
      title: Text(
        l10n.accountSettingsDeleteAccount,
        style: TextStyle(color: error),
      ),
      subtitle: Text(switch (scheduled) {
        // The server's hourly deletion can fail and leave the account.
        final date? when date.isBefore(now) => l10n.accountDeletionOverdueRow(
          deletionDate(formatter, date),
        ),
        final date? => l10n.accountDeletionScheduledRow(
          deletionDate(formatter, date),
        ),
        null => l10n.accountSettingsOpensWeb,
      }),
      trailing: Icon(Icons.open_in_new, color: error),
      onTap: onDelete,
    ),
  ];
}
