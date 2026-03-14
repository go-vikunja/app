import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/utils/constants.dart';
import 'package:vikunja_app/domain/entities/auth_model.dart';
import 'package:vikunja_app/domain/entities/server.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/domain/entities/version.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/main.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';
import 'package:vikunja_app/presentation/widgets/version_mismatch_dialog.dart';

VersionMismatchType? checkVersionCompatibility(
  Version serverVersion,
  Version? apiMinCompatible,
) {
  if (apiMinCompatible != null) {
    if (appBuiltForVersion.isOlderThanOrEqual(serverVersion) &&
        apiMinCompatible.isOlderThanOrEqual(appBuiltForVersion)) {
      return null;
    }
    if (serverVersion.isOlderThanOrEqual(appBuiltForVersion)) {
      return VersionMismatchType.serverTooOld;
    }
    return VersionMismatchType.appTooOld;
  }

  if (serverVersion != appBuiltForVersion) {
    return VersionMismatchType.unknown;
  }
  return null;
}

class InitPage extends ConsumerWidget {
  const InitPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: checkLoginToken(ref),
      builder: (context, asyncSnapshot) {
        if (asyncSnapshot.connectionState == ConnectionState.done &&
            asyncSnapshot.data != null) {
          return VikunjaErrorWidget(
            error: asyncSnapshot.data ?? "Unknown error occurred.",
          );
        } else {
          return Scaffold(body: LoadingWidget());
        }
      },
    );
  }

  Future<Object?> checkLoginToken(WidgetRef ref) async {
    var server = await ref.read(settingsRepositoryProvider).getServer();
    var token = await ref.read(settingsRepositoryProvider).getUserToken();
    var refreshCookie = await ref
        .read(settingsRepositoryProvider)
        .getRefreshCookie();

    if (server != null && token != null) {
      return checkServer(ref, server, token, refreshCookie);
    }

    globalNavigatorKey.currentState?.pushReplacementNamed("/login");
    return null;
  }

  Future<Object?> checkServer(
    WidgetRef ref,
    String server,
    String token,
    String? refreshCookie,
  ) async {
    ref
        .read(authDataProvider.notifier)
        .set(AuthModel(server, token, refreshCookie: refreshCookie));

    Version? serverVersion;
    Version? apiMinCompatible;

    Response<Server> info = await ref.read(serverRepositoryProvider).getInfo();
    if (info.isSuccessful) {
      final serverInfo = info.toSuccess().body;
      Sentry.configureScope(
        (scope) => scope.setTag('server.version', serverInfo.version ?? "-"),
      );

      serverVersion = Version.fromServerString(serverInfo.version ?? "-");
      if (serverInfo.apiMinCompatible != null) {
        apiMinCompatible = Version.fromString(serverInfo.apiMinCompatible!);
      }
    }

    return checkUser(ref, serverVersion, apiMinCompatible);
  }

  Future<Object?> checkUser(
    WidgetRef ref,
    Version? serverVersion,
    Version? apiMinCompatible,
  ) async {
    var userResponse = await ref.read(userRepositoryProvider).getCurrentUser();
    if (userResponse.isSuccessful) {
      ref.read(currentUserProvider.notifier).set(userResponse.toSuccess().body);

      onLoginSuccess(ref, serverVersion, apiMinCompatible);
    } else if (userResponse.isError) {
      onLoginError(ref, userResponse.toError());
    } else {
      return userResponse.toException().exception;
    }

    return null;
  }

  Future<void> onLoginSuccess(
    WidgetRef ref,
    Version? serverVersion,
    Version? apiMinCompatible,
  ) async {
    if (serverVersion != null) {
      final mismatchType = checkVersionCompatibility(
        serverVersion,
        apiMinCompatible,
      );
      if (mismatchType != null) {
        await showDialog<void>(
          context: ref.context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return VersionMismatchDialog(
              serverVersion: serverVersion,
              mismatchType: mismatchType,
            );
          },
        );
      }
    }

    globalNavigatorKey.currentState?.pushReplacementNamed("/home");
  }

  Future<Object?> onLoginError(
    WidgetRef ref,
    ErrorResponse<User> userResponse,
  ) async {
    if (userResponse.statusCode == 401) {
      ref.read(settingsRepositoryProvider).saveUserToken(null);
      ref.read(settingsRepositoryProvider).saveRefreshCookie(null);

      if (ref.context.mounted) {
        ScaffoldMessenger.of(ref.context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(ref.context).loginExpiredMessage),
          ),
        );
      }

      globalNavigatorKey.currentState?.pushReplacementNamed("/login");
      return null;
    }

    return userResponse.error["message"];
  }
}
