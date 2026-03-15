import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/core/utils/constants.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/main.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';
import 'package:vikunja_app/presentation/manager/init_controller.dart';
import 'package:vikunja_app/presentation/widgets/version_mismatch_dialog.dart';

class InitPage extends ConsumerWidget {
  const InitPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(initControllerProvider, (previous, next) {
      next.whenData((outcome) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!context.mounted) return;

          switch (outcome) {
            case InitGoLogin(:final loginExpired):
              if (loginExpired) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context).loginExpiredMessage,
                    ),
                  ),
                );
              }
              globalNavigatorKey.currentState?.pushReplacementNamed('/login');
            case InitGoHome(:final serverVersion):
              if (serverVersion != null &&
                  serverVersion != supportedServerVersion) {
                await showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return VersionMismatchDialog(serverVersion: serverVersion);
                  },
                );
              }
              globalNavigatorKey.currentState?.pushReplacementNamed('/home');
          }
        });
      });
    });

    final initState = ref.watch(initControllerProvider);

    return initState.when(
      data: (_) => const LoadingWidget(),
      loading: () => const LoadingWidget(),
      error: (err, _) => VikunjaErrorWidget(
        error: err,
        onRetry: () => ref.invalidate(initControllerProvider),
      ),
    );
  }
}
