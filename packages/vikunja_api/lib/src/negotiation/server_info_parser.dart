import 'package:vikunja_api/src/negotiation/max_file_size.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// Reads a `GET /info` body. Missing, null or mistyped fields fall back to
/// defaults, so only a missing `version` string throws a [FormatException].
ServerInfo parseServerInfo(Map<String, Object?> json) {
  final version = json['version'];
  if (version is! String) {
    throw FormatException('/info has no string "version"', version);
  }

  final maxFileSize = switch (json['max_file_size']) {
    final String size => size,
    final num size => size.toString(),
    _ => null,
  };
  final legal = _map(json['legal']);
  final auth = _map(json['auth']);
  final local = _map(auth['local']);
  final openId = _map(auth['openid_connect']);

  return ServerInfo(
    version: ServerVersion.tryParse(version),
    rawVersion: version.trim(),
    frontendUrl: _webUri(json['frontend_url']),
    motd: _string(json['motd']),
    linkSharingEnabled: _bool(json['link_sharing_enabled']),
    maxFileSize: maxFileSize ?? '',
    maxFileSizeBytes: maxFileSize == null
        ? null
        : maxFileSizeInBytes(maxFileSize),
    maxItemsPerPage: switch (_int(json['max_items_per_page'])) {
      final int perPage when perPage >= 1 => perPage,
      _ => 50,
    },
    availableMigrators: _strings(json['available_migrators']),
    taskAttachmentsEnabled: _bool(json['task_attachments_enabled']),
    enabledBackgroundProviders: _strings(json['enabled_background_providers']),
    totpEnabled: _bool(json['totp_enabled']),
    legal: _legalLinks(legal),
    caldavEnabled: _bool(json['caldav_enabled']),
    auth: AuthMethods(
      localEnabled: _bool(local['enabled']),
      registrationEnabled: _bool(local['registration_enabled']),
      ldapEnabled: _bool(_map(auth['ldap'])['enabled']),
      openIdConnectEnabled: _bool(openId['enabled']),
      openIdProviders: List.unmodifiable(_openIdProviders(openId['providers'])),
    ),
    emailRemindersEnabled: _bool(json['email_reminders_enabled']),
    userDeletionEnabled: _bool(json['user_deletion_enabled']),
    taskCommentsEnabled: _bool(json['task_comments_enabled']),
    demoModeEnabled: _bool(json['demo_mode_enabled']),
    webhooksEnabled: _bool(json['webhooks_enabled']),
    publicTeamsEnabled: _bool(json['public_teams_enabled']),
    allowIconChanges: _bool(json['allow_icon_changes']),
    enabledProFeatures: Set.unmodifiable(
      _strings(json['enabled_pro_features']),
    ),
    concurrentWrites: switch (json['concurrent_writes']) {
      final bool value => value,
      _ => null,
    },
  );
}

LegalLinks _legalLinks(Map<String, Object?> legal) {
  final imprint = _webUri(legal['imprint_url']);
  final privacy = _webUri(legal['privacy_policy_url']);
  final candidates = switch (legal['links']) {
    final List<Object?> listed => [
      for (final link in listed.map(_map))
        (_string(link['text']).trim(), _webUri(link['url'])),
    ],
    _ => [
      (LegalLink.imprintText, imprint),
      (LegalLink.privacyPolicyText, privacy),
    ],
  };
  // A set drops only an exact repeat: the server sends one address under two
  // texts, like a keyed "Impressum" beside the imprint, and the web shows both.
  final links = {
    for (final (text, url) in candidates)
      if (text.isNotEmpty && url != null) LegalLink(text: text, url: url),
  }.toList();
  Uri? named(String text) =>
      links.where((link) => link.text == text).firstOrNull?.url;
  return LegalLinks(
    imprintUrl: imprint ?? named(LegalLink.imprintText),
    privacyPolicyUrl: privacy ?? named(LegalLink.privacyPolicyText),
    links: List.unmodifiable(links),
  );
}

Iterable<OpenIdProvider> _openIdProviders(Object? value) sync* {
  if (value is! List<Object?>) return;
  for (final entry in value) {
    final provider = _map(entry);
    final key = provider['key'];
    // The key names the provider in the server's callback route.
    if (key is! String || key.isEmpty) continue;
    final name = _string(provider['name']);
    yield OpenIdProvider(
      name: name.isEmpty ? key : name,
      key: key,
      authUrl: _webUri(provider['auth_url']),
      logoutUrl: _webUri(provider['logout_url']),
      clientId: _string(provider['client_id']),
      scope: _string(provider['scope']),
    );
  }
}

Map<String, Object?> _map(Object? value) =>
    value is Map<String, Object?> ? value : const {};

bool _bool(Object? value) => value is bool && value;

String _string(Object? value) => value is String ? value : '';

int? _int(Object? value) =>
    value is num && value.isFinite ? value.toInt() : null;

List<String> _strings(Object? value) => value is List<Object?>
    ? List.unmodifiable(value.whereType<String>())
    : const [];

// Links are shown to the user and opened externally, so only web links count.
Uri? _webUri(Object? value) {
  if (value is! String) return null;
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !(uri.isScheme('http') || uri.isScheme('https')) ||
      uri.host.isEmpty) {
    return null;
  }
  return uri;
}
