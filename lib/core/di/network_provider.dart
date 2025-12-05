import 'dart:io';
import 'dart:developer' as developer;

import 'package:cronet_http/cronet_http.dart' as cronet_http;
import 'package:cupertino_http/cupertino_http.dart' as cupertino_http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io_client;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/domain/entities/auth_model.dart';
import 'package:vikunja_app/domain/entities/user.dart';

part 'network_provider.g.dart';

@Riverpod(keepAlive: true)
class AuthData extends _$AuthData {
  @override
  AuthModel? build() => null;

  void set(AuthModel token) => state = token;
}

@Riverpod(keepAlive: true)
class CurrentUser extends _$CurrentUser {
  @override
  User? build() => null;

  void set(User user) => state = user;
}

/// Returns null if Cronet is unavailable or fails to initialize.
@Riverpod(keepAlive: true)
cronet_http.CronetEngine? cronetEngine(Ref ref) {
  if (!Platform.isAndroid) return null;

  try {
    final engine = cronet_http.CronetEngine.build(
      cacheMode: cronet_http.CacheMode.memory,
      cacheMaxSize: 1000000,
    );

    ref.onDispose(() {
      engine.close();
    });

    return engine;
  } catch (e) {
    developer.log(
      "Cronet engine creation failed: $e. Falling back to default client.",
    );
    return null;
  }
}

/// Uses Cronet on Android, CupertinoClient on iOS, IOClient as fallback.
@Riverpod(keepAlive: true)
http.Client httpClient(Ref ref) {
  http.Client client;

  if (Platform.isAndroid) {
    final engine = ref.watch(cronetEngineProvider);
    if (engine != null) {
      client = cronet_http.CronetClient.fromCronetEngine(engine);
    } else {
      client = io_client.IOClient();
    }
  } else if (Platform.isIOS || Platform.isMacOS) {
    try {
      final config =
          cupertino_http.URLSessionConfiguration.ephemeralSessionConfiguration()
            ..cache = cupertino_http.URLCache.withCapacity(
              memoryCapacity: 1000000,
            );
      client = cupertino_http.CupertinoClient.fromSessionConfiguration(config);
    } catch (e) {
      developer.log(
        "Error creating Cupertino client: $e. Falling back to default client.",
      );
      client = io_client.IOClient();
    }
  } else {
    client = io_client.IOClient();
  }

  ref.onDispose(() {
    client.close();
  });

  return client;
}

@Riverpod(keepAlive: true)
Client clientProvider(Ref ref) {
  final authData = ref.watch(authDataProvider);
  final httpClient = ref.watch(httpClientProvider);

  final client = Client(
    base: authData?.address ?? '',
    token: authData?.token,
    httpClient: httpClient,
  );

  return client;
}
