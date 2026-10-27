import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';

/// A server certificate as the trust sheet shows it and a pin stores it.
@immutable
final class CertificateInfo {
  const new({
    required this.sha256,
    required this.subject,
    required this.issuer,
    required this.notBefore,
    required this.notAfter,
    this.der,
  });

  factory fromX509(X509Certificate certificate) => CertificateInfo(
    sha256: sha256Of(certificate.der),
    subject: certificate.subject,
    issuer: certificate.issuer,
    notBefore: certificate.startValidity.toUtc(),
    notAfter: certificate.endValidity.toUtc(),
    der: Uint8List.fromList(certificate.der),
  );

  /// Throws a [FormatException] unless [json] holds every field of
  /// [toJson].
  factory fromJson(Map<Object?, Object?> json) {
    final sha256 = json['sha256'];
    if (sha256 is! String || !_sha256Hex.hasMatch(sha256)) {
      throw const FormatException('sha256 is not 64 upper-case hex digits');
    }
    return CertificateInfo(
      sha256: sha256,
      subject: _string(json, 'subject'),
      issuer: _string(json, 'issuer'),
      notBefore: _date(json, 'notBefore'),
      notAfter: _date(json, 'notAfter'),
    );
  }

  /// Upper-case hex, as `openssl x509 -fingerprint -sha256` prints it
  /// without the colons.
  static String sha256Of(List<int> der) =>
      crypto.sha256.convert(der).toString().toUpperCase();

  /// 64 upper-case hex characters over the DER encoding.
  final String sha256;
  final String subject;
  final String issuer;
  final DateTime notBefore;
  final DateTime notAfter;

  /// Only for a certificate just seen on the wire; never stored.
  final Uint8List? der;

  bool get selfSigned => subject == issuer;

  /// The 32 hex pairs of [sha256].
  List<String> get sha256Pairs => [
    for (var i = 0; i + 1 < sha256.length; i += 2) sha256.substring(i, i + 2),
  ];

  bool isExpiredAt(DateTime now) => now.isAfter(notAfter);

  bool isNotYetValidAt(DateTime now) => now.isBefore(notBefore);

  /// Renewed so often (ACME, Caddy's internal CA) that a pin on it breaks
  /// within weeks.
  bool get isShortLived =>
      notAfter.difference(notBefore) < const Duration(days: 100);

  Map<String, Object?> toJson() => {
    'sha256': sha256,
    'subject': subject,
    'issuer': issuer,
    'notBefore': notBefore.toUtc().toIso8601String(),
    'notAfter': notAfter.toUtc().toIso8601String(),
  };

  static final _sha256Hex = RegExp(r'^[0-9A-F]{64}$');

  @override
  bool operator ==(Object other) =>
      other is CertificateInfo &&
      other.sha256 == sha256 &&
      other.subject == subject &&
      other.issuer == issuer &&
      other.notBefore == notBefore &&
      other.notAfter == notAfter;

  @override
  int get hashCode => Object.hash(sha256, subject, issuer, notBefore, notAfter);

  @override
  String toString() => 'CertificateInfo($sha256, $subject)';
}

String _string(Map<Object?, Object?> json, String key) => switch (json[key]) {
  final String value => value,
  _ => throw FormatException('$key is not a string'),
};

DateTime _date(Map<Object?, Object?> json, String key) =>
    DateTime.parse(_string(json, key)).toUtc();
