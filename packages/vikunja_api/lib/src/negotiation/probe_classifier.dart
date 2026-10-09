import 'package:vikunja_api/src/negotiation/info_probe.dart';
import 'package:vikunja_api/src/negotiation/server_info_parser.dart';
import 'package:vikunja_api/src/negotiation/transport_failure.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

sealed class CandidateOutcome;

/// An outcome that needs no further request.
sealed class SettledOutcome extends CandidateOutcome;

final class VikunjaFound(final ServerConnection connection)
    extends SettledOutcome;

final class CandidateFailed(
  final ServerConnectionFailure failure, {
  final bool servesVikunjaWebApp = false,
}) extends SettledOutcome;

/// The answers redirect to the `/info` of another root. [ifNotFollowed] is
/// what they mean when the connector does not follow.
final class RedirectsTo(
  final Uri root, {
  required final ServerConnectionFailure ifNotFollowed,
  required final bool looksLikeLogin,
}) extends CandidateOutcome;

/// v1 reported a version that serves `/api/v2`, but the v2 probe got no HTTP
/// response.
final class V2Unverified(final InfoAnswer v1) extends CandidateOutcome;

final _loginLikeTarget = RegExp(
  'log-?in|sign-?in|sign_in|auth|sso|saml|oidc|openid|cdn-cgi/access|'
  '[?&](rd|redirect|redirect_uri|return_to|next)=',
  caseSensitive: false,
);

final _passwordInput = RegExp(
  r'''<input[^>]*type\s*=\s*["']?password''',
  caseSensitive: false,
);

// Vikunja answers every unknown path outside /api with its web app.
final _vikunjaWebApp = RegExp(
  r'<title>\s*Vikunja\s*</title>|window\.API_URL',
  caseSensitive: false,
);

final _trailingSlashes = RegExp(r'/+$');

/// Decides what the `/info` answers of both API versions at [root] mean.
CandidateOutcome classifyProbes(
  Uri root, {
  required InfoProbeResult v2,
  required InfoProbeResult v1,
}) {
  final v2Info = v2 is InfoAnswer ? v2.vikunjaInfo : null;
  final v1Info = v1 is InfoAnswer ? v1.vikunjaInfo : null;
  if (v1 is InfoAnswer &&
      v1Info != null &&
      v2 is InfoTransportError &&
      _mayServeV2(v1Info)) {
    return V2Unverified(v1);
  }

  final apiVersions = {
    if (v2Info != null) ApiVersion.v2,
    if (v1Info != null) ApiVersion.v1,
  };
  final infoJson = v2Info ?? v1Info;
  if (infoJson != null) {
    final info = parseServerInfo(infoJson);
    return VikunjaFound(
      ServerConnection(
        rootUri: root,
        apiVersions: Set.unmodifiable(apiVersions),
        info: info,
        capabilities: ServerCapabilities.derive(
          info: info,
          apiVersions: apiVersions,
        ),
      ),
    );
  }

  final answers = [v2, v1].whereType<InfoAnswer>().toList();
  final failed = _failed(root, v2: v2, v1: v1, answers: answers);
  final redirectedRoots = {
    for (final answer in answers) ?_redirectedRoot(root, answer),
  };
  if (redirectedRoots.length == 1) {
    return RedirectsTo(
      redirectedRoots.single,
      ifNotFollowed: failed.failure,
      looksLikeLogin: answers.any(_redirectsToLogin),
    );
  }
  return failed;
}

bool _mayServeV2(Map<String, Object?> info) {
  final version = ServerVersion.tryParse(info['version']! as String);
  return version == null || version.isAtLeast(2, 4);
}

CandidateFailed _failed(
  Uri root, {
  required InfoProbeResult v2,
  required InfoProbeResult v1,
  required List<InfoAnswer> answers,
}) {
  for (final answer in answers) {
    final proxy = _loginProxy(root, answer);
    if (proxy != null) return CandidateFailed(proxy);
  }

  final transportFailures = [
    for (final result in [v2, v1])
      if (result is InfoTransportError)
        transportFailure(root, result.exception),
  ];
  // One probe failing on the network leaves open whether this is Vikunja.
  if (transportFailures.isNotEmpty) {
    return CandidateFailed(mostInformative(transportFailures));
  }

  final unavailable = answers
      .where((answer) => answer.statusCode >= 500 || answer.statusCode == 429)
      .firstOrNull;
  if (unavailable != null) {
    return CandidateFailed(
      ServerUnavailable(
        root,
        statusCode: unavailable.statusCode,
        retryAfter: _retryAfter(unavailable),
      ),
    );
  }

  return CandidateFailed(
    NotAVikunjaServer(root, statusCode: answers.last.statusCode),
    servesVikunjaWebApp: answers.any(
      (answer) => answer.isHtml && _vikunjaWebApp.hasMatch(answer.body),
    ),
  );
}

// Only the delay-seconds form; Vikunja's rate limiter sends no other.
Duration? _retryAfter(InfoAnswer answer) {
  final seconds = int.tryParse(answer.header('retry-after')?.trim() ?? '');
  return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
}

// Besides a target that keeps the probe path, an http to https redirect of
// the same host that drops the path counts, as in `return 301 https://$host;`.
Uri? _redirectedRoot(Uri root, InfoAnswer answer) {
  if (!answer.isRedirect) return null;
  final target = answer.redirectTarget;
  if (target == null ||
      target.hasQuery ||
      target.host.isEmpty ||
      target.userInfo.isNotEmpty) {
    return null;
  }
  final upgrades = root.isScheme('http') && target.isScheme('https');
  if (!upgrades && !target.isScheme(root.scheme)) return null;

  final probePath = answer.requestUri.path.substring(root.path.length);
  final path = target.path.replaceFirst(_trailingSlashes, '');
  final String rootPath;
  if (path.endsWith(probePath)) {
    rootPath = path.substring(0, path.length - probePath.length);
  } else if (upgrades &&
      target.host == root.host &&
      (path.isEmpty || path == root.path)) {
    rootPath = root.path;
  } else {
    return null;
  }

  final redirected = Uri(
    scheme: target.scheme,
    host: target.host,
    port: target.hasPort ? target.port : null,
    path: rootPath,
  );
  return redirected == root ? null : redirected;
}

bool _redirectsToLogin(InfoAnswer answer) {
  final target = answer.isRedirect ? answer.redirectTarget : null;
  return target != null &&
      _loginLikeTarget.hasMatch('${target.path}?${target.query}');
}

ServerConnectionFailure? _loginProxy(Uri root, InfoAnswer answer) {
  if (answer.isRedirect) {
    final target = answer.redirectTarget;
    if (target == null) return null;
    final leavesHost = target.host != answer.requestUri.host;
    return leavesHost || _redirectsToLogin(answer)
        ? BehindLoginProxy(root, redirectTarget: target)
        : null;
  }

  // Vikunja serves /info without authentication, so any 401 comes from a
  // proxy; oauth2-proxy and Authelia omit the challenge for JSON requests.
  final demandsCredentials = switch (answer.statusCode) {
    401 || 407 => true,
    403 => answer.header('www-authenticate') != null,
    _ => false,
  };
  if (demandsCredentials ||
      (answer.isHtml && _passwordInput.hasMatch(answer.body))) {
    return BehindLoginProxy(root);
  }
  return null;
}
