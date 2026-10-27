import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/network/network_profile.dart';
import 'package:vikunja_mobile/core/network/network_profile_providers.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/core/network/profile_http_client.dart';
import 'package:vikunja_mobile/core/network/secret_scrubbing.dart';

part 'realtime_providers.g.dart';

final _log = Logger('Realtime');

/// Opens sockets with the app's `User-Agent`, never an `Origin`: the
/// server refuses an Origin it does not know.
@Riverpod(keepAlive: true)
RealtimeConnector realtimeConnector(Ref ref) => ProfileRealtimeConnector(
  profiles: ref.watch(networkProfilesProvider),
  userAgent: ref.watch(clientIdentityProvider).userAgent,
);

/// Applies the origin's connection profile to each upgrade, as the Dios'
/// adapter does to requests: the cleartext consent for ws://, the headers,
/// and the pinned, CA-trusting or client-certificate client. The socket
/// is not a Dio request, so it needs this hook of its own.
final class ProfileRealtimeConnector implements RealtimeConnector {
  new({required this._profiles, required this._userAgent});

  final NetworkProfiles _profiles;
  final String _userAgent;

  @override
  Future<RealtimeSocket> connect(
    Uri url, {
    Map<String, String> headers = const {},
  }) async {
    final origin = OriginKey.of(url);
    final profile = await _profiles.forOrigin(origin);
    if (!origin.isSecure && !(profile?.hasCleartextConsent ?? false)) {
      throw CleartextBlockedException(origin.toString());
    }
    final sent = <String, String>{
      for (final MapEntry(:key, :value) in headers.entries)
        if (key.toLowerCase() != 'user-agent') key: value,
    };
    final present = {for (final name in sent.keys) name.toLowerCase()};
    for (final MapEntry(:key, :value) in (profile?.headers ?? {}).entries) {
      if (!present.contains(key.toLowerCase())) sent[key] = value;
    }
    sent['User-Agent'] = _userAgent;
    final connector = _connectorFor(profile);
    try {
      return await connector.connect(url, headers: sent);
    } on Object catch (error) {
      if ((profile?.hasHeaders ?? false) &&
          (error is FormatException || error is ArgumentError)) {
        _log.info('A stored setting was refused: ${error.runtimeType}');
        throw ConnectionProfileIncompleteException(origin.toString());
      }
      // dart:io reports the server's TLS alert only on the upgrade's first
      // read, as an HttpException naming it.
      if (origin.isSecure &&
          error is IOException &&
          mentionsClientCertificateRefusal('$error')) {
        throw ClientCertificateRefusedException(origin.toString());
      }
      if (profile != null &&
          error is! RealtimeUpgradeRefused &&
          quotesSecret(profile.secrets, [error])) {
        _log.info('Error text dropped: ${error.runtimeType}');
        // Unknown kinds take the connection's default path, as a socket
        // error does.
        throw textFreeLike(error) ?? const SocketException('');
      }
      rethrow;
    }
  }

  RealtimeConnector _connectorFor(NetworkProfile? profile) {
    if (profile == null || !profile.needsDartIo) {
      return const IoRealtimeConnector();
    }
    final SecurityContext context;
    try {
      context = profileSecurityContext(profile);
    } on Object catch (error) {
      if (error is! TlsException && error is! ArgumentError) rethrow;
      _log.info('Stored TLS settings refused: ${error.runtimeType}');
      throw ConnectionProfileIncompleteException(profile.origin.toString());
    }
    return IoRealtimeConnector(
      createHttpClient: () => profileHttpClient(
        profile,
        context: context,
        onPinMismatch: (seen) => unawaited(
          _profiles
              .recordPinMismatch(profile.origin, seen)
              .catchError(
                (Object error) =>
                    _log.info('Mismatch not recorded: ${error.runtimeType}'),
              ),
        ),
      ),
    );
  }
}
