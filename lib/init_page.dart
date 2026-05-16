import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/core/utils/constants.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/main.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';
import 'package:vikunja_app/presentation/manager/init_controller.dart';
import 'package:vikunja_app/presentation/manager/init_controller.dart';
import 'package:vikunja_app/presentation/widgets/version_mismatch_dialog.dart';

class InitPage extends ConsumerStatefulWidget {
  const InitPage({super.key});

  @override
  ConsumerState<InitPage> createState() => _InitPageState();
}

class _InitPageState extends ConsumerState<InitPage> {
  @override
  Widget build(BuildContext context) {
    ref.listen(initControllerProvider, (_, next) {
      next.whenData((outcome) => _handleOutcome(context, outcome));
    });

    final initState = ref.watch(initControllerProvider);

    return initState.when(
      loading: () => const LoadingWidget(),
      error: (err, _) => VikunjaErrorWidget(
        error: err,
        onRetry: () => ref.invalidate(initControllerProvider),
        onSecondaryAction: () {
          // LoginPage clears any saved auth (and server address) in initState.
          globalNavigatorKey.currentState?.pushReplacementNamed('/login');
        },
        secondaryActionLabel: AppLocalizations.of(context).logout,
      ),
      data: (_) => const LoadingWidget(),
    );
  }

  void _handleOutcome(BuildContext context, InitOutcome outcome) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;

      switch (outcome) {
        case InitGoLogin(:final loginExpired, :final serverVersion):
          if (serverVersion != null &&
              !serverVersion.isCompatibleWith(minimumServerVersion)) {
            await showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return VersionMismatchDialog(serverVersion: serverVersion);
              },
            );
            if (!context.mounted) return;
          }

          if (loginExpired) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context).loginExpiredMessage),
              ),
            );
          }

          globalNavigatorKey.currentState?.pushReplacementNamed('/login');

        case InitGoHome(:final serverVersion):
          if (serverVersion != null &&
              !serverVersion.isCompatibleWith(minimumServerVersion)) {
            await showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return VersionMismatchDialog(serverVersion: serverVersion);
              },
            );
            if (!context.mounted) return;
          }

          globalNavigatorKey.currentState?.pushReplacementNamed('/home');
      }
    });
  }
}
