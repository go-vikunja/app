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

      try {
        var user = await ref.read(userRepositoryProvider).getCurrentUser();
        ref.read(currentUserProvider.notifier).set(user);
        globalNavigatorKey.currentState?.pushNamed("/home");
      } catch (e) {
        globalNavigatorKey.currentState?.pushNamed("/login");
      }

      //TODO display this message on 401 when error handling complete
      // if (VikunjaGlobal.of(context).expired) {
      //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      //       content: Text("Login has expired. Please reenter your details!")));
      //   setState(() {
      //     _serverController.text = VikunjaGlobal.of(context).client.base;
      //     _usernameController.text =
      //         VikunjaGlobal.of(context).currentUser?.username ?? "";
      //   });
      // }
    } else {
      globalNavigatorKey.currentState?.pushNamed("/login");
    }
  }
}
