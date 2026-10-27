import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart'
    show mentionsClientCertificateRefusal;
import 'package:vikunja_mobile/core/network/certificate_info.dart';
import 'package:vikunja_mobile/core/network/network_profile.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';

final _log = Logger('CertificateProbe');

enum CertificateProbeProblem { unreachable, timeout, notTls }

sealed class CertificateProbeResult {
  const new();
}

final class ProbedCertificate extends CertificateProbeResult {
  const new(this.certificate, {this.deviceTrusted = false});

  final CertificateInfo certificate;

  /// Whether the device's own trusted certificates accept it. False also
  /// when that could not be checked, and on Android for a user-installed
  /// CA, which dart:io does not see.
  final bool deviceTrusted;
}

final class CertificateProbeFailed extends CertificateProbeResult {
  const new(this.problem);

  final CertificateProbeProblem problem;
}

/// Whether a CA file vouches for an origin's server certificate.
sealed class CaCheck {
  const new();
}

/// The chain verified, also when the server then refused the client
/// certificate.
final class CaTrusted extends CaCheck {
  const new();
}

final class CaNotTrusted extends CaCheck {
  const new(this.leaf);

  final CertificateInfo leaf;
}

final class CaCheckFailed extends CaCheck {
  const new(this.problem);

  final CertificateProbeProblem problem;
}

/// Not only certificates, a private key, too large, or unreadable.
final class CaFileInvalid extends CaCheck {
  const new();
}

/// TLS handshakes without HTTP: nothing but the ClientHello (with SNI for
/// a host name) reaches the server.
final class CertificateProbe {
  const new({
    this._profiles,
    this.timeout = const Duration(seconds: 5),
    @visibleForTesting this.deviceTrust,
  });

  final NetworkProfiles? _profiles;
  final Duration timeout;

  /// The device's trusted certificates; [SecurityContext.defaultContext]
  /// when null.
  final SecurityContext? deviceTrust;

  static final _pemBlock = RegExp('-----BEGIN ([A-Z0-9 ]+)-----');

  /// The leaf certificate [origin] presents, whoever issued it.
  Future<CertificateProbeResult> fetch(OriginKey origin) async {
    X509Certificate? leaf;
    final outcome = await _handshake(origin, SecurityContext(), (certificate) {
      leaf ??= certificate;
      return false;
    });
    if (leaf case final certificate?) {
      return ProbedCertificate(
        CertificateInfo.fromX509(certificate),
        deviceTrusted: await _deviceTrusts(origin),
      );
    }
    return switch (outcome) {
      _Connected(:final peer?) => ProbedCertificate(
        CertificateInfo.fromX509(peer),
      ),
      _Failed(:final problem) => CertificateProbeFailed(problem),
      _ => const CertificateProbeFailed(CertificateProbeProblem.notTls),
    };
  }

  /// Verifies [origin]'s chain against [pem] alone, presenting the
  /// origin's stored client certificate when there is one.
  Future<CaCheck> verifyWithCa(OriginKey origin, String pem) async {
    if (pem.length > NetworkProfiles.maxCaPemLength ||
        pem.contains('PRIVATE KEY')) {
      return const CaFileInvalid();
    }
    final blocks = _pemBlock.allMatches(pem).map((match) => match[1]).toList();
    if (blocks.isEmpty || blocks.any((label) => label != 'CERTIFICATE')) {
      return const CaFileInvalid();
    }
    final context = SecurityContext();
    try {
      context.setTrustedCertificatesBytes(utf8.encode(pem));
    } on Object catch (error) {
      if (error is! TlsException && error is! ArgumentError) rethrow;
      _log.info('CA file refused: ${error.runtimeType}');
      return const CaFileInvalid();
    }
    await _addClientCertificate(origin, context);
    X509Certificate? leaf;
    final outcome = await _handshake(origin, context, (certificate) {
      leaf ??= certificate;
      return false;
    });
    if (leaf case final certificate?) {
      return CaNotTrusted(CertificateInfo.fromX509(certificate));
    }
    return switch (outcome) {
      _Connected() || _ClientCertificateAlert() => const CaTrusted(),
      _Failed(:final problem) => CaCheckFailed(problem),
      _NotTls() => const CaCheckFailed(CertificateProbeProblem.notTls),
    };
  }

  /// A second handshake that only the device's own trusted certificates
  /// verify.
  Future<bool> _deviceTrusts(OriginKey origin) async {
    var refused = false;
    final outcome = await _handshake(
      origin,
      deviceTrust ?? SecurityContext.defaultContext,
      (_) {
        refused = true;
        return false;
      },
    );
    return outcome is _Connected && !refused;
  }

  Future<void> _addClientCertificate(
    OriginKey origin,
    SecurityContext context,
  ) async {
    final NetworkProfile? profile;
    try {
      profile = await _profiles?.forOrigin(origin);
    } on Object catch (error) {
      _log.info('No client certificate for the check: ${error.runtimeType}');
      return;
    }
    if (profile?.clientCertificate == null) return;
    final ProfileSecrets(:pkcs12, :pkcs12Password) = profile!.secrets;
    if (pkcs12 == null || pkcs12Password == null) return;
    try {
      context
        ..useCertificateChainBytes(pkcs12, password: pkcs12Password)
        ..usePrivateKeyBytes(pkcs12, password: pkcs12Password);
    } on Object catch (error) {
      if (error is! TlsException && error is! ArgumentError) rethrow;
      _log.info('Stored client certificate unusable: ${error.runtimeType}');
    }
  }

  Future<_Outcome> _handshake(
    OriginKey origin,
    SecurityContext context,
    bool Function(X509Certificate certificate) onBadCertificate,
  ) async {
    final connecting = SecureSocket.connect(
      origin.host,
      origin.port,
      context: context,
      onBadCertificate: onBadCertificate,
      timeout: timeout,
    );
    try {
      final socket = await connecting.timeout(timeout);
      final peer = socket.peerCertificate;
      socket.destroy();
      return _Connected(peer);
    } on TimeoutException {
      unawaited(
        connecting.then((orphan) => orphan.destroy(), onError: (Object _) {}),
      );
      return const _Failed(CertificateProbeProblem.timeout);
    } on HandshakeException catch (error) {
      if (mentionsClientCertificateRefusal('$error')) {
        return const _ClientCertificateAlert();
      }
      return const _NotTls();
    } on TlsException {
      return const _NotTls();
    } on SocketException catch (error) {
      return _Failed(
        error.message.contains('timed out')
            ? CertificateProbeProblem.timeout
            : CertificateProbeProblem.unreachable,
      );
    }
  }
}

sealed class _Outcome {
  const new();
}

final class _Connected extends _Outcome {
  const new(this.peer);

  final X509Certificate? peer;
}

final class _ClientCertificateAlert extends _Outcome {
  const new();
}

final class _NotTls extends _Outcome {
  const new();
}

final class _Failed extends _Outcome {
  const new(this.problem);

  final CertificateProbeProblem problem;
}
