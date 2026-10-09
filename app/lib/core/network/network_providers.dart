import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/network/dio_factory.dart';

part 'network_providers.g.dart';

@Riverpod(keepAlive: true)
ClientIdentity clientIdentity(Ref ref) =>
    throw UnimplementedError('Overridden in bootstrap with the loaded value.');

@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final dio = createDio(userAgent: ref.watch(clientIdentityProvider).userAgent);
  ref.onDispose(dio.close);
  return dio;
}

@Riverpod(keepAlive: true)
ServerConnector serverConnector(Ref ref) =>
    DioServerConnector(ref.watch(dioProvider));
