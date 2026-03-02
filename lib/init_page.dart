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

class InitPage extends ConsumerStatefulWidget {
  const InitPage({super.key});

  @override
  ConsumerState<InitPage> createState() => _InitPageState();
}

class _InitPageState extends ConsumerState<InitPage> {
  int _retryCount = 0;
  bool _isRetrying = false;
  bool _shouldShowSnackbar = false;

  void _handleRetry() async {
    if (_isRetrying) return;

    setState(() {
      _isRetrying = true;
      _shouldShowSnackbar = false;
      _retryCount++;
    });

    // Keep button disabled for at least 3 seconds
    await Future.delayed(Duration(seconds: 3));

    if (mounted) {
      setState(() {
        _isRetrying = false;
        _shouldShowSnackbar = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      key: ValueKey(_retryCount),
      future: checkLoginToken(ref).timeout(
        Duration(seconds: 3),
        onTimeout: () {
          return AppLocalizations.of(context).connectionTimeout;
        },
      ),
      builder: (context, asyncSnapshot) {
        if (asyncSnapshot.connectionState == ConnectionState.done &&
            asyncSnapshot.data != null) {
          if (_shouldShowSnackbar && !_isRetrying) {
            _shouldShowSnackbar = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context).connectionTimeout,
                    ),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            });
          }
          return VikunjaErrorWidget(
            error: asyncSnapshot.data ?? "Unknown error occurred.",
            onRetry: _handleRetry,
            isRetrying: _isRetrying,
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
