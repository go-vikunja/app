import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/domain/entities/auth_model.dart';
import 'package:vikunja_app/main.dart';

class InitPage extends ConsumerWidget {
  const InitPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: checkLogin(ref),
      builder: (context, asyncSnapshot) {
        return Center(child: CircularProgressIndicator());
      },
    );
  }

  Future<void> checkLogin(WidgetRef ref) async {
    var server = await ref.read(settingsRepositoryProvider).getServer();
    var token = await ref.read(settingsRepositoryProvider).getUserToken();

    if (server != null && token != null) {
      ref.read(authDataProvider.notifier).set(AuthModel(server, token));

      var userResponse = await ref
          .read(userRepositoryProvider)
          .getCurrentUser();
      if (userResponse.isSuccessful) {
        ref
            .read(currentUserProvider.notifier)
            .set(userResponse.toSuccess().body);

        globalNavigatorKey.currentState?.pushReplacementNamed("/home");
      } else {
        if (userResponse.toError().statusCode == 401) {
          ref.read(settingsRepositoryProvider).saveUserToken(null);

          ScaffoldMessenger.of(ref.context).showSnackBar(
            SnackBar(
              content: Text("Login has expired. Please reenter your details!"),
            ),
          );

          globalNavigatorKey.currentState?.pushReplacementNamed("/login");
        } else {
          ScaffoldMessenger.of(
            ref.context,
          ).showSnackBar(SnackBar(content: Text("Unknown error occurred.")));
          globalNavigatorKey.currentState?.pushReplacementNamed("/login");
        }
      }
    } else {
      globalNavigatorKey.currentState?.pushReplacementNamed("/login");
    }
  }
}
