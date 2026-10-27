import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/misc.dart';
import 'package:vikunja_mobile/core/network/certificate_info.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/features/attachments/application/attachment_picker.dart';
import 'package:vikunja_mobile/features/connection/application/certificate_checks.dart';

import 'auth_fakes.dart';
import 'tls_fixtures.dart';

/// The handshakes of the certificate screen without a server: [fetched]
/// answers every fetch (a pending completer keeps it running), [caCheck]
/// every CA check; the origins and PEMs asked for are recorded.
final class FakeCertificateChecks implements CertificateChecks {
  new({CertificateProbeResult? fetched})
    : fetched =
          fetched ?? ProbedCertificate(tlsFixtureCertificate('selfsigned.pem'));

  CertificateProbeResult fetched;
  Completer<CertificateProbeResult>? pending;
  CaCheck caCheck = const CaTrusted();
  final List<OriginKey> fetches = [];
  final List<String> checkedPems = [];

  Override get providerOverride =>
      certificateChecksProvider.overrideWithValue(this);

  @override
  Future<CertificateProbeResult> fetch(OriginKey origin) {
    fetches.add(origin);
    return pending?.future ?? Future.value(fetched);
  }

  @override
  Future<CaCheck> verifyWithCa(OriginKey origin, String pem) async {
    checkedPems.add(pem);
    return caCheck;
  }
}

/// A [NetworkProfiles] over the same stores the app gets from [auth], as
/// another instance of the same isolate would be.
NetworkProfiles profilesOver(AuthFakes auth) => NetworkProfiles(
  preferences: auth.preferences,
  secureStore: auth.secureStore,
);

/// A different certificate than the self-signed fixture, as a renewed one
/// would be.
final CertificateInfo renewedCertificate = CertificateInfo(
  sha256: 'AB' * 32,
  subject: '/CN=Rurana test renewed (dummy)',
  issuer: '/CN=Rurana test renewed (dummy)',
  notBefore: DateTime.utc(2026, 10),
  notAfter: DateTime.utc(2027, 10),
);

final CertificateInfo thirdCertificate = CertificateInfo(
  sha256: 'CD' * 32,
  subject: '/CN=Rurana test other (dummy)',
  issuer: '/CN=Rurana test other CA (dummy)',
  notBefore: DateTime.utc(2026, 9),
  notAfter: DateTime.utc(2027, 9),
);

/// A copy of a fixture where the document picker would leave it, to check
/// that the copy is deleted. Synchronous, so that widget tests can call it.
PickedFile pickedCopyOf(
  String fixture, {
  required Directory directory,
  String? name,
}) {
  final copy = File('${directory.path}/picked-${fixture.hashCode}')
    ..writeAsBytesSync(tlsFixture(fixture));
  return PickedFile(path: copy.path, name: name ?? fixture);
}
