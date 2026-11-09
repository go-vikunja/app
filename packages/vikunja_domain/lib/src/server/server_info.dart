import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/server/server_version.dart';

/// The public `GET /info` document. Field names follow
/// `pkg/routes/api/shared/info.go` of the Vikunja server; both API versions
/// return the same body.
@immutable
final class ServerInfo {
  const new({
    required this.version,
    this.rawVersion = '',
    this.frontendUrl,
    this.motd = '',
    this.linkSharingEnabled = false,
    this.maxFileSize = '',
    this.maxFileSizeBytes,
    this.maxItemsPerPage = 50,
    this.availableMigrators = const [],
    this.taskAttachmentsEnabled = false,
    this.enabledBackgroundProviders = const [],
    this.totpEnabled = false,
    this.legal = const LegalLinks(),
    this.caldavEnabled = false,
    this.auth = const AuthMethods(),
    this.emailRemindersEnabled = false,
    this.userDeletionEnabled = false,
    this.taskCommentsEnabled = false,
    this.demoModeEnabled = false,
    this.webhooksEnabled = false,
    this.publicTeamsEnabled = false,
    this.allowIconChanges = false,
    this.enabledProFeatures = const {},
    this.concurrentWrites,
  });

  /// Null when the server reported a version string we cannot interpret.
  final ServerVersion? version;

  /// The version string exactly as reported, also when [version] is null.
  final String rawVersion;
  final Uri? frontendUrl;
  final String motd;
  final bool linkSharingEnabled;

  /// Human-readable limit as configured on the server, e.g. `20MB`.
  final String maxFileSize;
  final int? maxFileSizeBytes;
  final int maxItemsPerPage;
  final List<String> availableMigrators;
  final bool taskAttachmentsEnabled;

  /// `upload` and/or `unsplash`.
  final List<String> enabledBackgroundProviders;
  final bool totpEnabled;
  final LegalLinks legal;
  final bool caldavEnabled;
  final AuthMethods auth;
  final bool emailRemindersEnabled;
  final bool userDeletionEnabled;
  final bool taskCommentsEnabled;
  final bool demoModeEnabled;
  final bool webhooksEnabled;
  final bool publicTeamsEnabled;
  final bool allowIconChanges;

  /// Licensed features: `admin_panel`, `time_tracking`, `audit_logs`,
  /// `user_invites`. Reported since 2.4.0.
  final Set<String> enabledProFeatures;

  /// False on SQLite-backed servers, where writes must be serialized.
  /// Null on servers older than 2.4.0, which do not report it.
  final bool? concurrentWrites;
}

@immutable
final class LegalLinks {
  const new({this.imprintUrl, this.privacyPolicyUrl, this.links = const []});

  /// `imprint_url`, or the listed link the server names `Imprint` when only
  /// the list has it.
  final Uri? imprintUrl;

  /// `privacy_policy_url`, or the listed link the server names
  /// `Privacy Policy` when only the list has it.
  final Uri? privacyPolicyUrl;

  /// Every legal link in the server's order, the imprint and the privacy
  /// policy included; two links with one address are both kept when their
  /// texts differ. Listed by the server since 2.8.0, built from the two URLs
  /// before.
  final List<LegalLink> links;
}

@immutable
final class LegalLink {
  const new({required this.text, required this.url});

  /// The texts the server gives the deprecated imprint and privacy policy in
  /// its list, which the app shows in its own words.
  static const imprintText = 'Imprint';
  static const privacyPolicyText = 'Privacy Policy';

  /// As the server's admin wrote it, untranslated.
  final String text;
  final Uri url;

  @override
  bool operator ==(Object other) =>
      other is LegalLink && other.text == text && other.url == url;

  @override
  int get hashCode => Object.hash(text, url);

  @override
  String toString() => 'LegalLink($url)';
}

@immutable
final class AuthMethods {
  const new({
    this.localEnabled = false,
    this.registrationEnabled = false,
    this.ldapEnabled = false,
    this.openIdConnectEnabled = false,
    this.openIdProviders = const [],
  });

  final bool localEnabled;
  final bool registrationEnabled;
  final bool ldapEnabled;
  final bool openIdConnectEnabled;
  final List<OpenIdProvider> openIdProviders;
}

@immutable
final class OpenIdProvider {
  const new({
    required this.name,
    required this.key,
    this.authUrl,
    this.logoutUrl,
    this.clientId = '',
    this.scope = '',
  });

  final String name;
  final String key;
  final Uri? authUrl;
  final Uri? logoutUrl;
  final String clientId;
  final String scope;
}
