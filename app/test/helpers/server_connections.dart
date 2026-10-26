import 'package:vikunja_domain/vikunja_domain.dart';

ServerInfo _info({
  required String version,
  String motd = '',
  bool ldap = false,
  List<OpenIdProvider> openIdProviders = const [],
  Set<String> proFeatures = const {},
  List<String> backgroundProviders = const ['upload'],
  bool publicTeams = false,
  bool totp = true,
  bool demoMode = false,
  LegalLinks legal = const LegalLinks(),
  bool localAuth = true,
  bool registration = true,
  Uri? frontendUrl,
}) => ServerInfo(
  version: ServerVersion.tryParse(version),
  rawVersion: version,
  frontendUrl: frontendUrl,
  motd: motd,
  linkSharingEnabled: true,
  maxFileSize: '20MB',
  maxFileSizeBytes: 20 * 1024 * 1024,
  taskAttachmentsEnabled: true,
  enabledBackgroundProviders: backgroundProviders,
  totpEnabled: totp,
  legal: legal,
  caldavEnabled: true,
  auth: AuthMethods(
    localEnabled: localAuth,
    registrationEnabled: localAuth && registration,
    ldapEnabled: ldap,
    openIdConnectEnabled: openIdProviders.isNotEmpty,
    openIdProviders: openIdProviders,
  ),
  emailRemindersEnabled: true,
  userDeletionEnabled: true,
  taskCommentsEnabled: true,
  demoModeEnabled: demoMode,
  webhooksEnabled: true,
  publicTeamsEnabled: publicTeams,
  enabledProFeatures: proFeatures,
);

ServerConnection _connect(
  String root,
  ServerInfo info,
  Set<ApiVersion> apiVersions,
) => ServerConnection(
  rootUri: Uri.parse(root),
  apiVersions: apiVersions,
  info: info,
  capabilities: ServerCapabilities.derive(info: info, apiVersions: apiVersions),
);

ServerConnection legacyServer100({String root = 'https://old.example.com'}) =>
    _connect(root, _info(version: 'v1.0.0'), {ApiVersion.v1});

/// Older than 2.3.0, so it has no browser sign-in and is unsupported.
ServerConnection legacyServer200({
  String root = 'https://vikunja.example.com',
  List<OpenIdProvider> openIdProviders = const [],
}) => _connect(
  root,
  _info(version: 'v2.0.0', openIdProviders: openIdProviders),
  {ApiVersion.v1},
);

ServerConnection oauthServer230({
  String root = 'https://vikunja.example.com',
}) => _connect(root, _info(version: 'v2.3.0'), {ApiVersion.v1});

ServerConnection fullServer270({
  String root = 'https://tasks.example.org/vikunja',
  bool demoMode = false,
}) => _connect(
  root,
  _info(
    version: 'v2.7.0',
    motd: 'Maintenance on Sunday from 02:00 to 03:00.',
    ldap: true,
    openIdProviders: const [
      OpenIdProvider(name: 'Keycloak', key: 'keycloak'),
      OpenIdProvider(name: 'Authentik', key: 'authentik'),
    ],
    proFeatures: const {'time_tracking', 'admin_panel'},
    backgroundProviders: const ['upload', 'unsplash'],
    publicTeams: true,
    demoMode: demoMode,
    legal: LegalLinks(
      imprintUrl: Uri.parse('https://example.org/imprint'),
      privacyPolicyUrl: Uri.parse('javascript:alert(1)'),
    ),
  ),
  {ApiVersion.v1, ApiVersion.v2},
);

/// A 2.7 server with local accounts (single sign-on only without
/// [localAuth]), open [registration], invite links when [invites] and the
/// web at [frontendUrl] when given.
ServerConnection accountPagesServer270({
  String root = 'https://tasks.example.org/vikunja',
  bool localAuth = true,
  bool registration = true,
  bool invites = false,
  Uri? frontendUrl,
}) => _connect(
  root,
  _info(
    version: 'v2.7.0',
    localAuth: localAuth,
    registration: registration,
    frontendUrl: frontendUrl,
    proFeatures: {if (invites) 'user_invites'},
    openIdProviders: localAuth
        ? const []
        : const [OpenIdProvider(name: 'Keycloak', key: 'keycloak')],
  ),
  {ApiVersion.v1, ApiVersion.v2},
);

/// A 2.7 server whose /api/v2 is hidden, e.g. by a reverse proxy.
ServerConnection v1OnlyServer270({
  String root = 'https://vikunja.example.com',
}) => _connect(root, _info(version: 'v2.7.0'), {ApiVersion.v1});

ServerConnection unknownVersionServer({
  String root = 'https://fork.example.com',
  String version = 'custom-2024',
}) => _connect(root, _info(version: version), {ApiVersion.v1});

ServerConnection insecureServer({String root = 'http://192.168.1.20:3456'}) =>
    _connect(root, _info(version: 'v2.4.0'), {ApiVersion.v1, ApiVersion.v2});
