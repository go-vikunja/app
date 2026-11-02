import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/core/links/external_link_opener.dart';
import 'package:vikunja_mobile/features/about/presentation/about_page.dart';
import 'package:vikunja_mobile/features/home/application/app_version.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

// The About page and the ways to it at 200 % text in dark mode on a small
// phone, in English and German. Layout overflows are reported as test
// failures, so reaching the end of each scenario without an exception is
// the assertion.
void main() {
  const smallPhone = Size(320, 640);
  const locales = [Locale('en'), Locale('de')];

  void useWorstCase(WidgetTester tester, Locale locale) {
    usePhoneSurface(tester, logicalSize: smallPhone);
    useAccessibilityExtremes(tester);
    useLocale(tester, locale);
  }

  Finder scrollableOf(Type page) => find
      .descendant(of: find.byType(page), matching: find.byType(Scrollable))
      .first;

  Future<void> scrollToEnd(WidgetTester tester, Type page) async {
    final scrollable = scrollableOf(page);
    final position = tester.state<ScrollableState>(scrollable).position;
    for (var i = 0; i < 80 && position.extentAfter > 0; i++) {
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(position.extentAfter, 0);
  }

  for (final locale in locales) {
    testWidgets('the About page at 200 % in dark mode, its tap targets '
        'labelled and large enough (${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final semantics = tester.ensureSemantics();
      await pumpVikunjaApp(tester);
      unawaited(
        containerOf(tester).read(appRouterProvider).push(AppRoutes.about),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AboutPage), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await scrollToEnd(tester, AboutPage);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('the About page of a release, with the website and the '
        'source code, at 200 % in dark mode, its tap targets labelled and '
        'large enough (${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appVersionProvider.overrideWithValue(testAppVersion),
            externalLinkOpenerProvider.overrideWithValue(
              FakeExternalLinkOpener(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: appSupportedLocales,
            home: const AboutPage(
              sourceCode: 'https://code.example.org/rurana',
              site: 'https://rurana.example.org',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.scrollUntilVisible(
        find.text(l10n.aboutPrivacyPolicy),
        100,
        scrollable: scrollableOf(AboutPage),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.aboutPrivacyPolicy), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await scrollToEnd(tester, AboutPage);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('the connect screen with its About button at 200 % in dark '
        'mode (${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      await pumpVikunjaApp(tester);

      expect(find.byType(ConnectServerScreen), findsOneWidget);
      final about = find.text(l10n.aboutTitle);
      await tester.ensureVisible(about);
      await tester.pumpAndSettle();
      await tester.tap(about);
      await tester.pumpAndSettle();
      expect(find.byType(AboutPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("the Account tab's version line at 200 % in dark mode, a "
        'labelled tap target (${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final semantics = tester.ensureSemantics();
      await pumpSignedInApp(tester);
      await openTab(tester, l10n.tabAccount);

      await scrollToEnd(tester, AccountTab);
      expect(find.byTooltip(l10n.aboutTitle), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
