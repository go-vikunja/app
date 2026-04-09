import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/auth_model.dart';
import 'package:vikunja_app/domain/entities/server.dart';
import 'package:vikunja_app/domain/entities/version.dart';

sealed class InitOutcome {
  const InitOutcome();
}

class InitGoLogin extends InitOutcome {
  final bool loginExpired;
  final Version? serverVersion;

  const InitGoLogin({this.loginExpired = false, this.serverVersion});
}

class InitGoHome extends InitOutcome {
  final Version? serverVersion;

  const InitGoHome({required this.serverVersion});
}

final initControllerProvider = FutureProvider<InitOutcome>((ref) {
  return _runInit(ref).timeout(const Duration(seconds: 3));
});

Future<InitOutcome> _runInit(Ref ref) async {
  final settingsRepo = ref.read(settingsRepositoryProvider);

  final server = await settingsRepo.getServer();
  if (server == null) {
    return const InitGoLogin();
  }

  ref.read(authDataProvider.notifier).set(AuthModel(server));

  Version? serverVersion;
  final Response<Server> info = await ref
      .read(serverRepositoryProvider)
      .getInfo();
  if (info.isSuccessful) {
    Sentry.configureScope(
      (scope) =>
          scope.setTag('server.version', info.toSuccess().body.version ?? '-'),
    );

    serverVersion = Version.fromServerString(
      info.toSuccess().body.version ?? '-',
    );
  }

  final token = await settingsRepo.getUserToken();
  if (token == null) {
    return InitGoLogin(serverVersion: serverVersion);
  }

  await settingsRepo.getRefreshToken();

  final userResponse = await ref.read(userRepositoryProvider).getCurrentUser();

  if (userResponse.isSuccessful) {
    ref.read(currentUserProvider.notifier).set(userResponse.toSuccess().body);
    return InitGoHome(serverVersion: serverVersion);
  }

  if (userResponse.isError) {
    final err = userResponse.toError();
    if (err.statusCode == 401) {
      await settingsRepo.saveUserToken(null);
      await settingsRepo.saveRefreshToken(null);
      return InitGoLogin(loginExpired: true, serverVersion: serverVersion);
    }

    throw err.error['message'] ?? err.error;
  }

  throw userResponse.toException().exception;
}
