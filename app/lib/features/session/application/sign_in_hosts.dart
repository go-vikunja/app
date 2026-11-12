import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

final _log = Logger('SignInHosts');

const confirmedSignInHostsKey = 'auth.confirmed_sign_in_hosts';

/// A sign-in page on another origin than its server: the server receives
/// the code and the PKCE verifier for the account signed in at that page,
/// and can redeem them there (D23, R1).
@immutable
final class OtherSignInHost {
  const new({required this.server, required this.signInPage, this.origin});

  /// For texts: the hosts, with their schemes where they would read alike.
  final String server;
  final String signInPage;

  /// What a confirmation is remembered as; without one it is asked every
  /// time.
  final OriginKey? origin;
}

/// Where the browser sign-in for [connection] opens, when that is not the
/// server's own origin; built as the request the browser gets.
OtherSignInHost? otherSignInHost(ServerConnection connection) {
  final page = _withAsciiHost(
    AuthorizationRequest.create(connection, appOAuthClient).url,
  );
  final pageOrigin = OriginKey.tryOf(page);
  final serverOrigin = OriginKey.tryOf(connection.rootUri);
  if (pageOrigin != null &&
      serverOrigin != null &&
      _sameOrigin(pageOrigin, serverOrigin)) {
    return null;
  }
  var server = serverOrigin?.authority ?? connection.rootUri.authority;
  var signInPage =
      pageOrigin?.authority ?? '${page.scheme}://${page.authority}';
  if (server == signInPage) {
    server = '${connection.rootUri.scheme}://$server';
    signInPage = '${page.scheme}://$signInPage';
  }
  return OtherSignInHost(
    server: server,
    signInPage: signInPage,
    origin: pageOrigin,
  );
}

// Dart's Uri percent-encodes a non-ASCII host, where the server's root has
// punycode; the browser opens the punycode too.
Uri _withAsciiHost(Uri uri) {
  try {
    final host = Uri.decodeComponent(uri.host);
    final ascii = punycodeHost(host);
    return ascii == null || ascii == host ? uri : uri.replace(host: ascii);
  } on FormatException {
    return uri;
  }
}

// A host name with or without its trailing dot resolves to the same server.
bool _sameOrigin(OriginKey page, OriginKey server) =>
    page.scheme == server.scheme &&
    page.port == server.port &&
    _undotted(page.host) == _undotted(server.host);

String _undotted(String host) =>
    host.endsWith('.') ? host.substring(0, host.length - 1) : host;

/// Per account, the sign-in page on another host it last signed in at
/// after the user confirmed it. Only a sign-in that ends with the account
/// counts: a user who closes the browser because the page looks wrong is
/// asked again. Origins and account ids only, nothing secret. What cannot
/// be read counts as not confirmed, so the question comes again.
final class ConfirmedSignInHosts {
  const new(this._preferences);

  final PreferencesStore _preferences;

  Future<bool> isConfirmed(String accountId, OtherSignInHost host) async {
    final origin = host.origin;
    return origin != null && (await _read())[accountId] == '$origin';
  }

  /// [host] is null for a sign-in page on the server's own origin.
  Future<void> signedIn(String accountId, OtherSignInHost? host) =>
      _update((entries) {
        if (host?.origin case final origin?) {
          entries[accountId] = '$origin';
        } else {
          entries.remove(accountId);
        }
      });

  Future<void> forget(String accountId) =>
      _update((entries) => entries.remove(accountId));

  Future<Map<String, String>> _read() async {
    try {
      final stored = await _preferences.getString(confirmedSignInHostsKey);
      if (stored == null) return {};
      return {
        for (final MapEntry(:key, :value)
            in (jsonDecode(stored) as Map<String, Object?>).entries)
          if (value is String) key: value,
      };
    } on Object catch (error) {
      _log.info('Confirmed sign-in hosts not readable: ${error.runtimeType}');
      return {};
    }
  }

  Future<void> _update(
    void Function(Map<String, String> entries) change,
  ) async {
    final entries = await _read();
    final before = Map.of(entries);
    change(entries);
    if (mapEquals(before, entries)) return;
    try {
      if (entries.isEmpty) {
        await _preferences.remove(confirmedSignInHostsKey);
      } else {
        await _preferences.setString(
          confirmedSignInHostsKey,
          jsonEncode(entries),
        );
      }
    } on Object catch (error) {
      _log.info('Confirmed sign-in host not stored: ${error.runtimeType}');
    }
  }
}
