import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/network/client.dart';

part 'network_provider.g.dart';

@Riverpod(keepAlive: true)
class AuthToken extends _$AuthToken {
  @override
  String? build() => null;

  void set(String? token) => state = token;
}

@Riverpod(keepAlive: true)
class ServerAddress extends _$ServerAddress {
  @override
  String? build() => null;

  void set(String? token) => state = token;
}

@riverpod
Client clientProvider(Ref ref) {
  final token = ref.watch(authTokenProvider);
  final serverAddress = ref.watch(serverAddressProvider);

  Client client = Client(null); // TODO

  client.configure(token: token, baseUrl: serverAddress);
  return client;
}
