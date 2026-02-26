import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:vikunja_app/core/di/data_source_provider.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/data/data_sources/oauth_data_source.dart';
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
    final settingsRepo = ref.read(settingsRepositoryProvider);
    var server = await settingsRepo.getServer();
    var token = await settingsRepo.getUserToken();

    if (server != null && token != null) {
      // Check if this is an OAuth session
      final authType = await settingsRepo.getAuthType();
      if (authType == 'oauth') {
        return _restoreOAuthSession(ref, server, token);
      }
      return checkServer(ref, server, token);
    }

    globalNavigatorKey.currentState?.pushReplacementNamed("/login");
    return null;
  }

  Future<Object?> _restoreOAuthSession(
    WidgetRef ref,
    String server,
    String accessToken,
  ) async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final refreshToken = await settingsRepo.getRefreshToken();
    final expiresAt = await settingsRepo.getTokenExpiry();

    if (refreshToken == null) {
      // No refresh token — can't restore, go to login
      globalNavigatorKey.currentState?.pushReplacementNamed("/login");
      return null;
    }

    // Set up OAuth token manager so ClientProvider wires the refresh hook
    ref
        .read(oAuthTokenManagerProvider.notifier)
        .setTokens(
          OAuthTokenState(
            refreshToken: refreshToken,
            expiresAt:
                expiresAt ?? DateTime.now(), // Expired if no expiry stored
          ),
        );

    // If the access token is expired, refresh it now
    final tokenExpired =
        expiresAt == null ||
        expiresAt.isBefore(DateTime.now().add(const Duration(seconds: 30)));

    if (tokenExpired) {
      try {
        final oauthDataSource = ref.read(oAuthDataSourceProvider);
        final tokens = await oauthDataSource.refreshToken(
          baseUrl: server,
          refreshToken: refreshToken,
        );

        accessToken = tokens.accessToken;

        // Update stored tokens
        await settingsRepo.saveUserToken(tokens.accessToken);
        await settingsRepo.saveRefreshToken(tokens.refreshToken);
        final newExpiry = DateTime.now().add(
          Duration(seconds: tokens.expiresIn),
        );
        await settingsRepo.saveTokenExpiry(newExpiry);

        // Update OAuth manager with new refresh token
        ref
            .read(oAuthTokenManagerProvider.notifier)
            .setTokens(
              OAuthTokenState(
                refreshToken: tokens.refreshToken,
                expiresAt: newExpiry,
              ),
            );
      } on OAuthException {
        // Refresh failed — session is gone
        await settingsRepo.saveRefreshToken(null);
        await settingsRepo.saveTokenExpiry(null);
        await settingsRepo.saveAuthType(null);
        await settingsRepo.saveUserToken(null);
        globalNavigatorKey.currentState?.pushReplacementNamed("/login");
        return null;
      }
    }

    // Now proceed with normal server/user check using the (possibly refreshed) access token
    return checkServer(ref, server, accessToken);
  }

  Future<Object?> checkServer(
    WidgetRef ref,
    String server,
    String token,
  ) async {
    ref.read(authDataProvider.notifier).set(AuthModel(server, token));

    Version? serverVersion;

    Response<Server> info = await ref.read(serverRepositoryProvider).getInfo();
    if (info.isSuccessful) {
      Sentry.configureScope(
        (scope) => scope.setTag(
          'server.version',
          info.toSuccess().body.version ?? "-",
        ),
      );

      serverVersion = Version.fromServerString(
        info.toSuccess().body.version ?? "-",
      );
    }

    return checkUser(ref, serverVersion);
  }

  Future<Object?> checkUser(WidgetRef ref, Version? serverVersion) async {
    var userResponse = await ref.read(userRepositoryProvider).getCurrentUser();
    if (userResponse.isSuccessful) {
      ref.read(currentUserProvider.notifier).set(userResponse.toSuccess().body);

      onLoginSuccess(ref, serverVersion);
    } else if (userResponse.isError) {
      onLoginError(ref, userResponse.toError());
    } else {
      return userResponse.toException().exception;
    }

    return null;
  }

  Future<void> onLoginSuccess(WidgetRef ref, Version? serverVersion) async {
    if (serverVersion != null && serverVersion != supportedServerVersion) {
      await showDialog<void>(
        context: ref.context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return VersionMismatchDialog(serverVersion: serverVersion);
        },
      );
    }

    globalNavigatorKey.currentState?.pushReplacementNamed("/home");
  }

  Future<Object?> onLoginError(
    WidgetRef ref,
    ErrorResponse<User> userResponse,
  ) async {
    if (userResponse.statusCode == 401) {
      ref.read(settingsRepositoryProvider).saveUserToken(null);

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
