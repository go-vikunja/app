import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/network/certificate_probe.dart';
import 'package:vikunja_mobile/core/network/network_profile_providers.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';

export 'package:vikunja_mobile/core/network/certificate_probe.dart'
    show
        CaCheck,
        CaCheckFailed,
        CaFileInvalid,
        CaNotTrusted,
        CaTrusted,
        CertificateProbeFailed,
        CertificateProbeProblem,
        CertificateProbeResult,
        ProbedCertificate;

part 'certificate_checks.g.dart';

/// The TLS handshakes the certificate screen starts, apart from the
/// network so that screens can be tested without a server.
abstract interface class CertificateChecks {
  Future<CertificateProbeResult> fetch(OriginKey origin);

  Future<CaCheck> verifyWithCa(OriginKey origin, String pem);
}

final class _ProbeChecks implements CertificateChecks {
  const new(this._probe);

  final CertificateProbe _probe;

  @override
  Future<CertificateProbeResult> fetch(OriginKey origin) =>
      _probe.fetch(origin);

  @override
  Future<CaCheck> verifyWithCa(OriginKey origin, String pem) =>
      _probe.verifyWithCa(origin, pem);
}

@riverpod
CertificateChecks certificateChecks(Ref ref) =>
    _ProbeChecks(ref.watch(certificateProbeProvider));
