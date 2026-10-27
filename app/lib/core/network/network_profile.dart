import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:vikunja_mobile/core/network/certificate_info.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';

@immutable
final class PinnedCertificate {
  const new({required this.certificate, required this.trustedAt});

  factory fromJson(Map<Object?, Object?> json) => PinnedCertificate(
    certificate: CertificateInfo.fromJson(json),
    trustedAt: _date(json, 'trustedAt'),
  );

  final CertificateInfo certificate;
  final DateTime trustedAt;

  String get sha256 => certificate.sha256;

  Map<String, Object?> toJson() => {
    ...certificate.toJson(),
    'trustedAt': trustedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is PinnedCertificate &&
      other.certificate == certificate &&
      other.trustedAt == trustedAt;

  @override
  int get hashCode => Object.hash(certificate, trustedAt);
}

/// A certificate the server presented that did not match the pin.
@immutable
final class PinMismatch {
  const new({required this.certificate, required this.seenAt});

  factory fromJson(Map<Object?, Object?> json) => PinMismatch(
    certificate: CertificateInfo.fromJson(json),
    seenAt: _date(json, 'seenAt'),
  );

  final CertificateInfo certificate;
  final DateTime seenAt;

  String get sha256 => certificate.sha256;

  Map<String, Object?> toJson() => {
    ...certificate.toJson(),
    'seenAt': seenAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is PinMismatch &&
      other.certificate == certificate &&
      other.seenAt == seenAt;

  @override
  int get hashCode => Object.hash(certificate, seenAt);
}

/// A CA the user trusts for one origin. The PEM is public, so it lives in
/// the metadata; a file with a private key is refused before it gets here.
@immutable
final class CaCertificate {
  const new({
    required this.fileName,
    required this.pem,
    required this.importedAt,
  });

  factory fromJson(Map<Object?, Object?> json) => CaCertificate(
    fileName: _string(json, 'fileName'),
    pem: _string(json, 'pem'),
    importedAt: _date(json, 'importedAt'),
  );

  final String fileName;
  final String pem;
  final DateTime importedAt;

  Map<String, Object?> toJson() => {
    'fileName': fileName,
    'pem': pem,
    'importedAt': importedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is CaCertificate &&
      other.fileName == fileName &&
      other.pem == pem &&
      other.importedAt == importedAt;

  @override
  int get hashCode => Object.hash(fileName, pem, importedAt);
}

/// The PKCS#12 file and its password live in [ProfileSecrets].
@immutable
final class ClientCertificate {
  const new({required this.fileName, required this.importedAt});

  factory fromJson(Map<Object?, Object?> json) => ClientCertificate(
    fileName: _string(json, 'fileName'),
    importedAt: _date(json, 'importedAt'),
  );

  final String fileName;
  final DateTime importedAt;

  Map<String, Object?> toJson() => {
    'fileName': fileName,
    'importedAt': importedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is ClientCertificate &&
      other.fileName == fileName &&
      other.importedAt == importedAt;

  @override
  int get hashCode => Object.hash(fileName, importedAt);
}

/// Header values, the PKCS#12 bytes and its password, from secure storage.
/// Never part of a `toString`, of JSON metadata or of a log.
@immutable
final class ProfileSecrets {
  const new({this.headers = const {}, this.pkcs12, this.pkcs12Password});

  static const none = ProfileSecrets();

  final Map<String, String> headers;
  final Uint8List? pkcs12;

  /// A file password (D65), not an account password.
  final String? pkcs12Password;

  /// The texts that must never appear in an error or a log.
  Iterable<String> get secretTexts => [
    ...headers.values,
    if (pkcs12Password case final password? when password.isNotEmpty) password,
  ].where((value) => value.isNotEmpty);

  @override
  String toString() => 'ProfileSecrets([redacted])';
}

/// One origin's connection settings: metadata from preferences, plus the
/// [secrets] when they were resolved for a request or an editor.
@immutable
final class NetworkProfile {
  const new({
    required this.origin,
    this.revision = 1,
    this.pin,
    this.caCertificate,
    this.clientCertificate,
    this.headerNames = const [],
    this.cleartextConsentAt,
    this.lastPinMismatch,
    this.secrets = ProfileSecrets.none,
    this.unknownFields = const {},
  }) : assert(
         pin == null || caCertificate == null,
         'A pin and a trusted CA exclude each other',
       );

  /// Throws a [FormatException] for an entry this version cannot read, and
  /// for one with both a pin and a CA, which must fail closed.
  factory fromJson(OriginKey origin, Object? json) {
    if (json is! Map<Object?, Object?>) {
      throw const FormatException('A profile entry is not an object');
    }
    final pin = _object(json, 'pin');
    final ca = _object(json, 'caCertificate');
    if (pin != null && ca != null) {
      throw const FormatException('A profile has both a pin and a CA');
    }
    final revision = json['revision'];
    if (revision is! int || revision < 0) {
      throw const FormatException('revision is not a non-negative int');
    }
    final headerNames = switch (json['headerNames']) {
      null => const <String>[],
      final List<Object?> names when names.every((name) => name is String) =>
        List<String>.unmodifiable(names.cast<String>()),
      _ => throw const FormatException('headerNames is not a string list'),
    };
    final mismatch = _object(json, 'lastPinMismatch');
    final client = _object(json, 'clientCertificate');
    final consent = json['cleartextConsentAt'];
    return NetworkProfile(
      origin: origin,
      revision: revision,
      pin: pin == null ? null : PinnedCertificate.fromJson(pin),
      caCertificate: ca == null ? null : CaCertificate.fromJson(ca),
      clientCertificate: client == null
          ? null
          : ClientCertificate.fromJson(client),
      headerNames: headerNames,
      cleartextConsentAt: switch (consent) {
        null => null,
        final String value => DateTime.parse(value).toUtc(),
        _ => throw const FormatException('cleartextConsentAt is no date'),
      },
      lastPinMismatch: mismatch == null ? null : PinMismatch.fromJson(mismatch),
      unknownFields: Map.unmodifiable({
        for (final MapEntry(:key, :value) in json.entries)
          if (key is String && !_knownFields.contains(key)) key: value,
      }),
    );
  }

  /// The first 32 hex digits of the SHA-256 of the origin string; names
  /// the secure-storage entry.
  static String idFor(OriginKey origin) => crypto.sha256
      .convert(utf8.encode(origin.toString()))
      .toString()
      .substring(0, 32);

  static const _knownFields = {
    'id',
    'revision',
    'pin',
    'caCertificate',
    'clientCertificate',
    'headerNames',
    'cleartextConsentAt',
    'lastPinMismatch',
  };

  final OriginKey origin;

  /// Grows with every edit, never with a recorded mismatch.
  final int revision;
  final PinnedCertificate? pin;
  final CaCertificate? caCertificate;
  final ClientCertificate? clientCertificate;

  /// The only headers sent, in the order the user entered them.
  final List<String> headerNames;
  final DateTime? cleartextConsentAt;
  final PinMismatch? lastPinMismatch;
  final ProfileSecrets secrets;

  /// Fields a newer version wrote, kept when this one writes the entry.
  final Map<String, Object?> unknownFields;

  String get id => idFor(origin);

  /// A pin, a CA or a client certificate: only dart:io can do these, so
  /// the request leaves the native stack.
  bool get needsDartIo =>
      pin != null || caCertificate != null || clientCertificate != null;

  bool get hasCleartextConsent => cleartextConsentAt != null;

  bool get hasHeaders => headerNames.isNotEmpty;

  /// Whether secure storage holds something for this profile.
  bool get namesSecrets => headerNames.isNotEmpty || clientCertificate != null;

  /// Nothing that changes a request is stored.
  bool get isEmpty =>
      pin == null &&
      caCertificate == null &&
      clientCertificate == null &&
      headerNames.isEmpty &&
      cleartextConsentAt == null;

  /// Only the headers the metadata names, with their stored values.
  Map<String, String> get headers => {
    for (final name in headerNames) name: ?secrets.headers[name],
  };

  NetworkProfile withSecrets(ProfileSecrets secrets) => NetworkProfile(
    origin: origin,
    revision: revision,
    pin: pin,
    caCertificate: caCertificate,
    clientCertificate: clientCertificate,
    headerNames: headerNames,
    cleartextConsentAt: cleartextConsentAt,
    lastPinMismatch: lastPinMismatch,
    secrets: secrets,
    unknownFields: unknownFields,
  );

  /// Without secrets; the null-able fields take the value of their
  /// `clear…` flag or the given one.
  NetworkProfile copyWith({
    int? revision,
    PinnedCertificate? pin,
    bool clearPin = false,
    CaCertificate? caCertificate,
    bool clearCaCertificate = false,
    ClientCertificate? clientCertificate,
    bool clearClientCertificate = false,
    List<String>? headerNames,
    DateTime? cleartextConsentAt,
    bool clearCleartextConsent = false,
    PinMismatch? lastPinMismatch,
    bool clearLastPinMismatch = false,
  }) => NetworkProfile(
    origin: origin,
    revision: revision ?? this.revision,
    pin: clearPin ? null : pin ?? this.pin,
    caCertificate: clearCaCertificate
        ? null
        : caCertificate ?? this.caCertificate,
    clientCertificate: clearClientCertificate
        ? null
        : clientCertificate ?? this.clientCertificate,
    headerNames: headerNames ?? this.headerNames,
    cleartextConsentAt: clearCleartextConsent
        ? null
        : cleartextConsentAt ?? this.cleartextConsentAt,
    lastPinMismatch: clearLastPinMismatch
        ? null
        : lastPinMismatch ?? this.lastPinMismatch,
    unknownFields: unknownFields,
  );

  Map<String, Object?> toJson() => {
    ...unknownFields,
    'id': id,
    'revision': revision,
    'pin': ?pin?.toJson(),
    'caCertificate': ?caCertificate?.toJson(),
    'clientCertificate': ?clientCertificate?.toJson(),
    if (headerNames.isNotEmpty) 'headerNames': headerNames,
    'cleartextConsentAt': ?cleartextConsentAt?.toUtc().toIso8601String(),
    'lastPinMismatch': ?lastPinMismatch?.toJson(),
  };

  /// Metadata only; the header names count, never a value.
  @override
  String toString() =>
      'NetworkProfile($origin, revision: $revision, '
      'pin: ${pin != null}, ca: ${caCertificate != null}, '
      'clientCertificate: ${clientCertificate != null}, '
      'headers: ${headerNames.length}, '
      'cleartextConsent: ${cleartextConsentAt != null})';
}

Map<Object?, Object?>? _object(Map<Object?, Object?> json, String key) =>
    switch (json[key]) {
      null => null,
      final Map<Object?, Object?> value => value,
      _ => throw FormatException('$key is not an object'),
    };

String _string(Map<Object?, Object?> json, String key) => switch (json[key]) {
  final String value => value,
  _ => throw FormatException('$key is not a string'),
};

DateTime _date(Map<Object?, Object?> json, String key) =>
    DateTime.parse(_string(json, key)).toUtc();
