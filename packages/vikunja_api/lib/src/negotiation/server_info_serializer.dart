import 'package:vikunja_domain/vikunja_domain.dart';

/// The inverse of `parseServerInfo`, in the server's own JSON format, so a
/// stored connection can be restored with the same parser.
Map<String, Object?> serverInfoToJson(ServerInfo info) => {
  'version': info.rawVersion.isNotEmpty
      ? info.rawVersion
      : (info.version?.raw ?? ''),
  'frontend_url': _uri(info.frontendUrl),
  'motd': info.motd,
  'link_sharing_enabled': info.linkSharingEnabled,
  // Absent and empty differ: the server falls back to 20 MiB for an empty
  // value, and the parser reports no limit for an absent one.
  'max_file_size': ?(info.maxFileSize.isEmpty && info.maxFileSizeBytes == null
      ? null
      : info.maxFileSize),
  'max_items_per_page': info.maxItemsPerPage,
  'available_migrators': [...info.availableMigrators],
  'task_attachments_enabled': info.taskAttachmentsEnabled,
  'enabled_background_providers': [...info.enabledBackgroundProviders],
  'totp_enabled': info.totpEnabled,
  'legal': {
    'imprint_url': _uri(info.legal.imprintUrl),
    'privacy_policy_url': _uri(info.legal.privacyPolicyUrl),
  },
  'caldav_enabled': info.caldavEnabled,
  'auth': {
    'local': {
      'enabled': info.auth.localEnabled,
      'registration_enabled': info.auth.registrationEnabled,
    },
    'ldap': {'enabled': info.auth.ldapEnabled},
    'openid_connect': {
      'enabled': info.auth.openIdConnectEnabled,
      'providers': [
        for (final provider in info.auth.openIdProviders)
          {
            'name': provider.name,
            'key': provider.key,
            'auth_url': _uri(provider.authUrl),
            'logout_url': _uri(provider.logoutUrl),
            'client_id': provider.clientId,
            'scope': provider.scope,
          },
      ],
    },
  },
  'email_reminders_enabled': info.emailRemindersEnabled,
  'user_deletion_enabled': info.userDeletionEnabled,
  'task_comments_enabled': info.taskCommentsEnabled,
  'demo_mode_enabled': info.demoModeEnabled,
  'webhooks_enabled': info.webhooksEnabled,
  'public_teams_enabled': info.publicTeamsEnabled,
  'allow_icon_changes': info.allowIconChanges,
  'enabled_pro_features': [...info.enabledProFeatures],
  'concurrent_writes': ?info.concurrentWrites,
};

String _uri(Uri? uri) => uri?.toString() ?? '';
