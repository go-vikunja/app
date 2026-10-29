import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/layout/window_layout.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/app/theme/status_bar_style.dart';
import 'package:vikunja_mobile/app/theme/theme_providers.dart';
import 'package:vikunja_mobile/app/widgets/app_lock_gate.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
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
      highContrastTheme: AppTheme.highContrastLight(
        colorScheme: schemes?.light,
      ),
      highContrastDarkTheme: AppTheme.highContrastDark(
        colorScheme: schemes?.dark,
      ),
      themeMode: ref.watch(themeModeProvider),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) => _StatusBarFallback(
        child: _LargeWindowDialogs(
          child: AppLockGate(
            child: AnnouncerHost(
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
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// The status bar's style for a page without an app bar or a region of its
/// own. Flutter keeps the last style when it finds none, which after a
/// Cupertino sheet is the light text of the sheet's top gap. App bars and
/// the lock cover still decide where they are.
class _StatusBarFallback extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: statusBarStyleOn(Theme.of(context).colorScheme.surface),
    child: child,
  );
}

/// Material dialogs at most [ReadableWidth.dialog] wide on large windows,
/// for every dialog route below; the date and time pickers keep their own
/// sizes (`pickerFormatsBuilder`). The theme stays in the tree either way,
/// so a resize keeps the app's state.
class _LargeWindowDialogs extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  static final BoxConstraints _constraints = ReadableWidth
      .defaultDialogConstraints
      .copyWith(maxWidth: ReadableWidth.dialog);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: WindowLayout.of(context).capsWidths
          ? theme.copyWith(
              dialogTheme: theme.dialogTheme.copyWith(
                constraints: _constraints,
              ),
            )
          : theme,
      child: child,
    );
  }
}
