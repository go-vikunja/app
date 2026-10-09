import 'dart:math';

import 'package:meta/meta.dart';
import 'package:vikunja_api/src/auth/oauth_client_config.dart';
import 'package:vikunja_api/src/auth/pkce.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// One browser sign-in attempt. Single use: a fresh verifier and state per
/// attempt.
@immutable
final class AuthorizationRequest {
  const new({
    required this.url,
    required this.state,
    required this.codeVerifier,
    required this.client,
  });

  /// Builds `{frontend_url}oauth/authorize?...` with PKCE S256. Without a
  /// `frontend_url`, or when an https server advertises an http one, the web
  /// app is assumed at the server root, where Vikunja serves it by default.
  factory create(
    ServerConnection connection,
    OAuthClientConfig client, {
    Random? random,
  }) {
    if (!client.redirectUri.scheme.startsWith('vikunja-')) {
      throw ArgumentError.value(
        client.redirectUri,
        'client.redirectUri',
        'Vikunja accepts only redirect schemes starting with "vikunja-"',
      );
    }
    final source = random ?? Random.secure();
    final codeVerifier = generateCodeVerifier(random: source);
    final state = generateState(random: source);
    final advertised = connection.info.frontendUrl;
    // Never downgrade an https server's sign-in page, e.g. for a stale
    // `service.publicurl` behind a TLS proxy. Upgrading the advertised URL
    // instead could hit a port without TLS.
    final frontend =
        advertised == null ||
            (connection.rootUri.isScheme('https') &&
                !advertised.isScheme('https'))
        ? connection.rootUri
        : advertised;
    final basePath = frontend.path.endsWith('/')
        ? frontend.path
        : '${frontend.path}/';
    final url = Uri(
      scheme: frontend.scheme,
      host: frontend.host,
      port: frontend.hasPort ? frontend.port : null,
      path: '${basePath}oauth/authorize',
      queryParameters: {
        'response_type': 'code',
        'client_id': client.clientId,
        'redirect_uri': client.redirectUri.toString(),
        'state': state,
        'code_challenge': codeChallengeS256(codeVerifier),
        'code_challenge_method': 'S256',
      },
    );
    return AuthorizationRequest(
      url: url,
      state: state,
      codeVerifier: codeVerifier,
      client: client,
    );
  }

  final Uri url;
  final String state;
  final String codeVerifier;
  final OAuthClientConfig client;

  /// Validates the redirect the browser returned and extracts the code.
  /// Throws an `AuthorizationCallbackException`.
  String codeFromCallback(Uri callback) {
    final expected = client.redirectUri;
    if (callback.scheme.toLowerCase() != expected.scheme.toLowerCase() ||
        callback.host.toLowerCase() != expected.host.toLowerCase() ||
        callback.path != expected.path) {
      throw const AuthorizationCallbackException(
        AuthorizationCallbackProblem.wrongRedirect,
      );
    }
    final Map<String, String> parameters;
    try {
      parameters = callback.queryParameters;
    } on FormatException {
      throw const AuthorizationCallbackException(
        AuthorizationCallbackProblem.wrongRedirect,
      );
    }
    if (!_constantTimeEquals(parameters['state'] ?? '', state)) {
      throw const AuthorizationCallbackException(
        AuthorizationCallbackProblem.stateMismatch,
      );
    }
    if (parameters['error'] case final error? when error.isNotEmpty) {
      throw AuthorizationCallbackException(
        AuthorizationCallbackProblem.errorResponse,
        error: error,
        errorDescription: parameters['error_description'],
      );
    }
    final code = parameters['code'];
    if (code == null || code.isEmpty) {
      throw const AuthorizationCallbackException(
        AuthorizationCallbackProblem.missingCode,
      );
    }
    return code;
  }

  @override
  String toString() => 'AuthorizationRequest(${url.host})';
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return difference == 0;
}

enum AuthorizationCallbackProblem {
  wrongRedirect,
  stateMismatch,
  missingCode,

  /// The authorization server redirected with an RFC 6749 `error`. Vikunja's
  /// web app shows its errors itself, so only a proxy or a future server
  /// does this.
  errorResponse,
}

final class AuthorizationCallbackException implements Exception {
  const new(this.problem, {this.error, this.errorDescription});

  final AuthorizationCallbackProblem problem;

  /// The `error` parameter, e.g. `access_denied`.
  final String? error;
  final String? errorDescription;

  @override
  String toString() => error == null
      ? 'AuthorizationCallbackException($problem)'
      : 'AuthorizationCallbackException($problem, $error)';
}
