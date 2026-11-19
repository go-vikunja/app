import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/network/certificate_info.dart';
import 'package:vikunja_mobile/core/network/network_profile.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';

final _log = Logger('ProfileTransport');

/// A server's stored headers added to a request's, where the request has
/// none of that name in any case: the requests and the realtime socket
/// apply them alike.
Map<String, Object?> withProfileHeaders(
  Map<String, Object?> request,
  Map<String, String> profile,
) {
  final present = {for (final name in request.keys) name.toLowerCase()};
  return {
    ...request,
    for (final MapEntry(:key, :value) in profile.entries)
      if (!present.contains(key.toLowerCase())) key: value,
  };
}

/// Records a certificate that did not match a server's pin, once per
/// origin and certificate until the stored record is cleared ("Keep
/// current"): a reconnecting socket or a retrying request would otherwise
/// read the stored settings under their write lock every time.
final class PinMismatchRecorder {
  new(this._profiles);

  final NetworkProfiles _profiles;
  final _recorded = <OriginKey, String>{};

  /// What the profile now says: without a stored mismatch the next one is
  /// recorded again.
  void sync(OriginKey origin, NetworkProfile? profile) {
    if (profile?.lastPinMismatch == null) _recorded.remove(origin);
  }

  void record(OriginKey origin, CertificateInfo seen) {
    if (_recorded[origin] == seen.sha256) return;
    _recorded[origin] = seen.sha256;
    unawaited(
      _profiles
          .recordPinMismatch(origin, seen)
          .catchError(
            (Object error) =>
                _log.info('Mismatch not recorded: ${error.runtimeType}'),
          ),
    );
  }
}
