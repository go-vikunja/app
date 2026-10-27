import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/network/dio_factory.dart';
import 'package:vikunja_mobile/core/network/network_profile_providers.dart';

part 'network_providers.g.dart';

@Riverpod(keepAlive: true)
ClientIdentity clientIdentity(Ref ref) =>
    throw UnimplementedError('Overridden in bootstrap with the loaded value.');

/// Each Dio owns its adapter over the shared profile table, which edits
/// change in place: rebuilding a Dio would tear down running syncs.
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final dio = createDio(
    userAgent: ref.watch(clientIdentityProvider).userAgent,
    profiles: ref.watch(networkProfilesProvider),
  );
  ref.onDispose(dio.close);
  return dio;
}

/// For the OAuth token endpoint: no auth interceptor, and a long receive
/// timeout, because the server rotates the refresh token as soon as it
/// receives a refresh, so an abandoned response loses the session.
@Riverpod(keepAlive: true)
Dio authDio(Ref ref) {
  final dio = createDio(
    userAgent: ref.watch(clientIdentityProvider).userAgent,
    profiles: ref.watch(networkProfilesProvider),
    receiveTimeout: const Duration(seconds: 60),
  );
  ref.onDispose(dio.close);
  return dio;
}

@Riverpod(keepAlive: true)
ServerConnector serverConnector(Ref ref) =>
    DioServerConnector(ref.watch(dioProvider));
