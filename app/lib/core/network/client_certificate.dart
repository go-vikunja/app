import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';

final _log = Logger('ClientCertificate');

enum ClientCertificateProblem { wrongPasswordOrUnsupported, empty, tooLarge }

const int maxClientCertificateBytes = 64 * 1024;

// BoringSSL refuses longer passwords (PEM_BUFSIZE) with an ArgumentError
// that would otherwise be the only hint.
const _maxPasswordLength = 1023;

/// Null when dart:io accepts [bytes] (PKCS#12, or PEM with the key) with
/// [password] as a client identity, exactly as a profile's
/// `SecurityContext` will load it.
ClientCertificateProblem? validateClientCertificate(
  Uint8List bytes,
  String password,
) {
  if (bytes.isEmpty) return ClientCertificateProblem.empty;
  if (bytes.length > maxClientCertificateBytes) {
    return ClientCertificateProblem.tooLarge;
  }
  if (password.length > _maxPasswordLength) {
    return ClientCertificateProblem.wrongPasswordOrUnsupported;
  }
  try {
    SecurityContext()
      ..useCertificateChainBytes(bytes, password: password)
      ..usePrivateKeyBytes(bytes, password: password);
    return null;
  } on Object catch (error) {
    if (error is! TlsException && error is! ArgumentError) rethrow;
    // The messages can quote file contents; the type is enough.
    _log.info('Client certificate refused: ${error.runtimeType}');
    return ClientCertificateProblem.wrongPasswordOrUnsupported;
  }
}
