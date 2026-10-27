import 'dart:convert';
import 'dart:typed_data';

import 'package:vikunja_mobile/core/network/network_profile.dart';
import 'package:vikunja_mobile/core/storage/secure_store.dart';

/// One secure-storage entry per origin, named by the profile id, since the
/// store cannot be enumerated.
final class NetworkProfileSecrets {
  new(this._store);

  final SecureStore _store;

  static String keyFor(String profileId) =>
      'network_profile.$profileId.secrets';

  /// Null when nothing is stored; throws a [FormatException] for an entry
  /// that cannot be read, and whatever the store throws.
  Future<ProfileSecrets?> read(String profileId) async {
    final stored = await _store.read(keyFor(profileId));
    if (stored == null || stored.isEmpty) return null;
    return decode(stored);
  }

  Future<void> write(String profileId, ProfileSecrets secrets) =>
      _store.write(keyFor(profileId), encode(secrets));

  Future<void> delete(String profileId) => _store.delete(keyFor(profileId));

  static String encode(ProfileSecrets secrets) => jsonEncode({
    'headers': secrets.headers,
    if (secrets.pkcs12 case final pkcs12?) 'pkcs12': base64.encode(pkcs12),
    'pkcs12Password': ?secrets.pkcs12Password,
  });

  static ProfileSecrets decode(String stored) {
    final Object? json;
    try {
      json = jsonDecode(stored);
    } on FormatException {
      throw const FormatException('Profile secrets are not JSON');
    }
    if (json is! Map<String, Object?>) {
      throw const FormatException('Profile secrets are not an object');
    }
    final headers = switch (json['headers']) {
      null => const <String, String>{},
      final Map<String, Object?> map
          when map.values.every((v) => v is String) =>
        Map<String, String>.unmodifiable(map.cast<String, String>()),
      _ => throw const FormatException('headers is not a string map'),
    };
    final pkcs12 = switch (json['pkcs12']) {
      null => null,
      final String encoded => _base64(encoded),
      _ => throw const FormatException('pkcs12 is not a string'),
    };
    final password = switch (json['pkcs12Password']) {
      null => null,
      final String value => value,
      _ => throw const FormatException('pkcs12Password is not a string'),
    };
    return ProfileSecrets(
      headers: headers,
      pkcs12: pkcs12,
      pkcs12Password: password,
    );
  }
}

// The decoder's message would quote the input.
Uint8List _base64(String encoded) {
  try {
    return base64.decode(encoded);
  } on FormatException {
    throw const FormatException('pkcs12 is not base64');
  }
}
