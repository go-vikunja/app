import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/notifications/presentation/notification_setup_screen.dart';
import 'package:vikunja_mobile/features/notifications/presentation/notifications_section.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/notification_ui_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';

/// Every notification screen at 200 % text on a small phone in dark mode,
/// in both languages, with the longest status lines.
void main() {
  const smallPhone = Size(320, 640);
  const locales = [Locale('en'), Locale('de')];

  void useWorstCase(WidgetTester tester, Locale locale) {
    usePhoneSurface(tester, logicalSize: smallPhone);
    useAccessibilityExtremes(tester);
    useLocale(tester, locale);
  }

  Future<void> scrollToEnd(WidgetTester tester, Finder scrollView) async {
    final position = tester
        .state<ScrollableState>(
          find
              .descendant(of: scrollView, matching: find.byType(Scrollable))
              .first,
        )
        .position;
    for (var i = 0; i < 50 && position.extentAfter > 0; i++) {
      await tester.drag(scrollView, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(position.extentAfter, 0);
  }

  for (final locale in locales) {
    testWidgets('setup screen, both steps (${locale.languageCode})', (
      tester,
    ) async {
      useWorstCase(tester, locale);
      final auth = AuthFakes(notificationsOnboarded: false);
      await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      );
      final notifications =
          NotificationFakes(
            capabilities: const NotificationCapabilities(
              permission: NotificationPermission.notAsked,
              exactAlarms: false,
            ),
          )..answerRequestWith(
            const NotificationCapabilities(
              permission: NotificationPermission.granted,
              exactAlarms: false,
            ),
          );
      await pumpVikunjaApp(tester, auth: auth, notifications: notifications);
      expect(find.byType(NotificationSetupScreen), findsOneWidget);
      await scrollToEnd(tester, find.byType(SingleChildScrollView));

      await tester.tap(
        find.text(lookupAppLocalizations(locale).notificationSetupTurnOn),
      );
      await tester.pumpAndSettle();
      await scrollToEnd(tester, find.byType(SingleChildScrollView));
      expect(tester.takeException(), isNull);
    }, variant: const TargetPlatformVariant({TargetPlatform.android}));

    testWidgets('notifications section with every status line '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final notifications = NotificationFakes(
        capabilities: const NotificationCapabilities(
          permission: NotificationPermission.denied,
          exactAlarms: false,
        ),
        scheduledCount: 120,
      );
      await pumpSignedInApp(tester, notifications: notifications);
      await openTab(tester, lookupAppLocalizations(locale).tabAccount);

      // Sections below it can take it out of the lazily built list again
      // by the end.
      await tester.scrollUntilVisible(
        find.byType(NotificationsSection),
        300,
        scrollable: find
            .descendant(
              of: find.byType(AccountTab),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsSection), findsOneWidget);
      await scrollToEnd(tester, find.byType(AccountTab));
      expect(tester.takeException(), isNull);
    });
  }
}
