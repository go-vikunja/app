import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/server/api_version.dart';
import 'package:vikunja_domain/src/server/capability.dart';
import 'package:vikunja_domain/src/server/server_info.dart';
import 'package:vikunja_domain/src/server/server_version.dart';

enum SupportTier {
  /// Without `/api/v2`: older than
  /// [ServerCapabilities.minimumSupportedVersion], or a version string that
  /// cannot be read.
  unsupported,

  /// 2.3, or a newer server whose proxy hides `/api/v2`: `/api/v1` only.
  oauth,

  /// 2.4 and newer with a reachable `/api/v2`.
  full,
}

@immutable
final class ServerCapabilities {
  const new _(this.tier, this._capabilities);

  factory derive({
    required ServerInfo info,
    required Set<ApiVersion> apiVersions,
  }) {
    final version = info.version;
    bool atLeast(int major, int minor) =>
        version != null && version.isAtLeast(major, minor);

    final hasV2 = apiVersions.contains(ApiVersion.v2);
    final pro = info.enabledProFeatures;
    final auth = info.auth;

    final capabilities = <Capability>{
      if (hasV2) Capability.apiV2,
      if (atLeast(2, 0) || hasV2) Capability.sessionRefresh,
      if (atLeast(2, 3) || hasV2) ...[
        Capability.oauthPkce,
        Capability.websocket,
      ],
      if (hasV2 && atLeast(2, 5)) Capability.bulkCreateTasks,
      if (hasV2 && atLeast(2, 6)) Capability.pendingEmail,
      if (hasV2 && atLeast(2, 7)) Capability.byIndexRedirect,
      if (auth.localEnabled) Capability.localAuth,
      if (auth.ldapEnabled) Capability.ldapAuth,
      if (auth.openIdConnectEnabled && auth.openIdProviders.isNotEmpty)
        Capability.openIdConnect,
      if (auth.registrationEnabled) Capability.registration,
      if (info.linkSharingEnabled) Capability.linkSharing,
      if (info.taskAttachmentsEnabled) Capability.taskAttachments,
      if (info.taskCommentsEnabled) Capability.taskComments,
      if (info.totpEnabled) Capability.totp,
      if (info.caldavEnabled) Capability.caldav,
      if (info.webhooksEnabled) Capability.webhooks,
      if (info.publicTeamsEnabled) Capability.publicTeams,
      if (info.userDeletionEnabled) Capability.userDeletion,
      if (info.emailRemindersEnabled) Capability.emailReminders,
      if (info.enabledBackgroundProviders.contains('upload'))
        Capability.backgroundUpload,
      if (info.enabledBackgroundProviders.contains('unsplash'))
        Capability.backgroundUnsplash,
      // Time entries and the admin API exist only on /api/v2.
      if (hasV2 && pro.contains('time_tracking')) Capability.timeTracking,
      if (hasV2 && pro.contains('admin_panel')) Capability.adminPanel,
      if (hasV2 && pro.contains('audit_logs')) Capability.auditLogs,
      if (hasV2 && pro.contains('user_invites')) Capability.userInvites,
    };

    return ServerCapabilities._(
      _tierFor(version, hasV2: hasV2),
      Set.unmodifiable(capabilities),
    );
  }

  // Browser sign-in (OAuth 2.0 + PKCE), the only sign-in method the app
  // offers, first shipped in 2.3.0.
  static const minimumSupportedVersion = ServerVersion(2, 3, 0);

  static SupportTier _tierFor(ServerVersion? version, {required bool hasV2}) {
    if (hasV2) return SupportTier.full;
    if (version != null && version >= minimumSupportedVersion) {
      return SupportTier.oauth;
    }
    return SupportTier.unsupported;
  }

  final SupportTier tier;
  final Set<Capability> _capabilities;

  bool has(Capability capability) => _capabilities.contains(capability);

  Set<Capability> get all => _capabilities;

  bool get isSupported => tier != SupportTier.unsupported;
}
