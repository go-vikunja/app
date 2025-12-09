import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/domain/entities/auth_model.dart';
import 'package:vikunja_app/domain/entities/user.dart';

part 'network_provider.g.dart';

@Riverpod(keepAlive: true)
class AuthData extends _$AuthData {
  @override
  AuthModel? build() => null;

  void set(AuthModel token) {
    state = token;
    ref.invalidate(clientProviderProvider);
  }
}

@Riverpod(keepAlive: true)
class CurrentUser extends _$CurrentUser {
  @override
  User? build() => null;

  void set(User user) => state = user;
}

@Riverpod(keepAlive: true)
class ClientProvider extends _$ClientProvider {

  @override
  Client build() {
    final authData = ref.read(authDataProvider);

    return Client(base: authData?.address ?? '', token: authData?.token);
  }

}
