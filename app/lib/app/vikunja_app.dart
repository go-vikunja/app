import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/app/theme/theme_providers.dart';
import 'package:vikunja_mobile/app/widgets/app_lock_gate.dart';
import 'package:vikunja_mobile/features/deep_links/presentation/deep_link_listener.dart';
import 'package:vikunja_mobile/features/notifications/presentation/notification_tap_listener.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/guest/guest_landing_listener.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/new_task_shortcut.dart';
import 'package:vikunja_mobile/features/share/presentation/share_intent_listener.dart';
import 'package:vikunja_mobile/features/widgets/presentation/widget_link_listener.dart';

class VikunjaApp extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemes = ref.watch(appColorSchemesProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: AppTheme.light(colorScheme: schemes?.light),
      darkTheme: AppTheme.dark(colorScheme: schemes?.dark),
      themeMode: ref.watch(themeModeProvider),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) => AppLockGate(
        child: NotificationTapListener(
          child: DeepLinkListener(
            child: WidgetLinkListener(
              child: NewTaskShortcutListener(
                child: ShareIntentListener(
                  child: GuestLandingListener(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
