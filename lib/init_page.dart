import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/auth_model.dart';
import 'package:vikunja_app/domain/entities/server.dart';
import 'package:vikunja_app/main.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';

class InitPage extends ConsumerWidget {
  const InitPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: checkLogin(ref),
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

  Future<Object?> checkLogin(WidgetRef ref) async {
    var server = await ref.read(settingsRepositoryProvider).getServer();
    var token = await ref.read(settingsRepositoryProvider).getUserToken();

    if (server != null && token != null) {
      ref.read(authDataProvider.notifier).set(AuthModel(server, token));

      Response<Server> info = await ref
          .read(serverRepositoryProvider)
          .getInfo();
      if (info.isSuccessful) {
        Sentry.configureScope(
          (scope) => scope.setTag(
            'server.version',
            info.toSuccess().body.version ?? "-",
          ),
        );
      }

      var userResponse = await ref
          .read(userRepositoryProvider)
          .getCurrentUser();
      if (userResponse.isSuccessful) {
        ref
            .read(currentUserProvider.notifier)
            .set(userResponse.toSuccess().body);

        globalNavigatorKey.currentState?.pushReplacementNamed("/home");
      } else if (userResponse.isError) {
        if (userResponse.toError().statusCode == 401) {
          ref.read(settingsRepositoryProvider).saveUserToken(null);

          ScaffoldMessenger.of(ref.context).showSnackBar(
            SnackBar(
              content: Text("Login has expired. Please reenter your details!"),
            ),
          );

          globalNavigatorKey.currentState?.pushReplacementNamed("/login");
        } else {
          return userResponse.toError().error["message"];
        }
      } else {
        return userResponse.toException().exception;
      }
    } else {
      globalNavigatorKey.currentState?.pushReplacementNamed("/login");
    }

    return null;
  }
}
