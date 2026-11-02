import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/l10n/licence_page_localizations.dart';
import 'package:vikunja_mobile/app/legal.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/links/external_link_opener.dart';
import 'package:vikunja_mobile/features/about/presentation/about_page.dart';
import 'package:vikunja_mobile/features/home/application/app_version.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fakes.dart';
import '../../helpers/guest_app.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  Finder aboutList() => find
      .descendant(of: find.byType(AboutPage), matching: find.byType(Scrollable))
      .first;

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 100, scrollable: aboutList());
    await tester.pumpAndSettle();
  }

  Future<void> expectNotices(WidgetTester tester) async {
    expect(find.byType(AboutPage), findsOneWidget);
    expect(find.text(en.aboutTitle), findsOneWidget);
    expect(find.text(en.aboutVersion('1.0.0', '42')), findsOneWidget);
    expect(find.text(copyrightNotice), findsOneWidget);
    expect(find.text(en.aboutUnofficial), findsOneWidget);
    for (final text in [
      if (siteUrl != null) ...[en.aboutPrivacyPolicy, en.aboutLegalNotice],
      en.aboutLicence,
      en.aboutNoWarranty,
      en.aboutLicences,
      if (sourceCodeUrl == null)
        en.aboutSourceCodeLater
      else
        en.aboutSourceCodeOpen,
      en.aboutNameAndLogo,
    ]) {
      await scrollTo(tester, find.text(text));
      expect(find.text(text), findsOneWidget);
    }
  }

  Finder versionLine() => find.text(en.accountAppVersion('1.0.0', '42'));

  Future<void> openFromAccountTab(WidgetTester tester) async {
    await openTab(tester, en.tabAccount);
    final accountList = find
        .descendant(
          of: find.byType(AccountTab),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      versionLine(),
      200,
      scrollable: accountList,
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip(en.aboutTitle), findsOneWidget);
    await tester.tap(versionLine());
    await tester.pumpAndSettle();
  }

  testWidgets('signed out, the connect screen opens About, and back returns '
      'to it', (tester) async {
    usePhoneSurface(tester);
    await pumpVikunjaApp(tester);
    expect(find.byType(ConnectServerScreen), findsOneWidget);

    final about = find.text(en.aboutTitle);
    await tester.ensureVisible(about);
    await tester.pumpAndSettle();
    await tester.tap(about);
    await tester.pumpAndSettle();

    await expectNotices(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ConnectServerScreen), findsOneWidget);
    expect(find.byType(AboutPage), findsNothing);
  });

  testWidgets('the connect screen keeps About from being opened while it '
      'connects', (tester) async {
    usePhoneSurface(tester);
    await pumpVikunjaApp(tester);

    await tester.enterText(find.byType(TextFormField), 'tasks.example.org');
    await tester.tap(find.text(en.connectContinue));
    await pumpFrames(tester, 3);

    final button = find.widgetWithText(TextButton, en.aboutTitle);
    await tester.ensureVisible(button);
    await pumpFrames(tester, 3);
    expect(tester.widget<TextButton>(button).onPressed, isNull);
  });

  testWidgets('signed in, the version line on the Account tab opens About', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await pumpSignedInApp(tester);

    await openFromAccountTab(tester);

    await expectNotices(tester);
  });

  testWidgets('a link-share guest opens About from the version line', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await pumpGuestApp(tester, auth: AuthFakes(), data: SyncFakes());

    await openFromAccountTab(tester);

    await expectNotices(tester);
  });

  testWidgets('adding another account shows no About button', (tester) async {
    usePhoneSurface(tester);
    await pumpSignedInApp(tester);

    unawaited(
      containerOf(tester).read(appRouterProvider).push(AppRoutes.addAccount),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ConnectServerScreen), findsOneWidget);
    expect(find.text(en.aboutTitle), findsNothing);
  });

  testWidgets('Licences opens the licence page with the app named', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await pumpVikunjaApp(tester);
    unawaited(
      containerOf(tester).read(appRouterProvider).push(AppRoutes.about),
    );
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text(en.aboutLicences));
    await tester.tap(find.text(en.aboutLicences));
    // The licences load in the background, behind a progress indicator.
    await pumpFrames(tester, 5);

    final page = tester.widget<LicensePage>(find.byType(LicensePage));
    expect(page.applicationName, en.appTitle);
    expect(page.applicationVersion, en.aboutVersion('1.0.0', '42'));
    expect(page.applicationLegalese, copyrightNotice);
    final pageLocalizations = MaterialLocalizations.of(
      tester.element(find.byType(LicensePage)),
    );
    expect(pageLocalizations.licensesPageTitle, 'Licences');
    expect(pageLocalizations.licensesPackageDetailText(2), '2 licences.');
    expect(find.text('Licenses'), findsNothing);
  });

  test("the licence page keeps Flutter's texts in German", () async {
    expect(licencePageLocalizations.isSupported(const Locale('de')), isFalse);
    expect(
      licencePageLocalizations.isSupported(const Locale('en', 'US')),
      isTrue,
    );
    final english = await licencePageLocalizations.load(const Locale('en'));
    expect(english.licensesPackageDetailText(1), '1 licence.');
    expect(english.backButtonTooltip, 'Back');
  });

  group('with the website', () {
    const site = 'https://rurana.example.org';

    Future<FakeExternalLinkOpener> pumpAbout(
      WidgetTester tester, {
      String? site = site,
      bool opens = true,
    }) async {
      final opener = FakeExternalLinkOpener(succeeds: opens);
      usePhoneSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appVersionProvider.overrideWithValue(testAppVersion),
            externalLinkOpenerProvider.overrideWithValue(opener),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: appSupportedLocales,
            home: AboutPage(site: site),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return opener;
    }

    testWidgets('a build without it has no links to it', (tester) async {
      await pumpAbout(tester, site: null);

      expect(find.text(en.aboutWebsiteHeading), findsNothing);
      expect(find.text(en.aboutPrivacyPolicy), findsNothing);
      expect(find.text(en.aboutLegalNotice), findsNothing);
      await scrollTo(tester, find.text(en.aboutNameAndLogo));
      expect(find.text(en.aboutPrivacyPolicy), findsNothing);
    });

    testWidgets('the privacy policy and the legal notice open in English', (
      tester,
    ) async {
      final opener = await pumpAbout(tester);

      expect(find.text(en.aboutWebsiteHeading), findsOneWidget);
      await tester.tap(find.text(en.aboutPrivacyPolicy));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.aboutLegalNotice));
      await tester.pumpAndSettle();

      expect(opener.opened, [
        Uri.parse('$site/en/privacy/'),
        Uri.parse('$site/en/legal/'),
      ]);
      expect(find.text(en.legalOpenFailed), findsNothing);
    });

    testWidgets('they open in German when the app is in German', (
      tester,
    ) async {
      useLocale(tester, const Locale('de'));
      final opener = await pumpAbout(tester);

      expect(find.text(de.aboutWebsiteHeading), findsOneWidget);
      await tester.tap(find.text(de.aboutPrivacyPolicy));
      await tester.pumpAndSettle();
      await tester.tap(find.text(de.aboutLegalNotice));
      await tester.pumpAndSettle();

      expect(opener.opened, [
        Uri.parse('$site/de/privacy/'),
        Uri.parse('$site/de/legal/'),
      ]);
    });

    testWidgets('a link that does not open says so', (tester) async {
      await pumpAbout(tester, opens: false);

      await tester.tap(find.text(en.aboutPrivacyPolicy));
      await tester.pumpAndSettle();

      expect(find.text(en.legalOpenFailed), findsOneWidget);
    });

    test('its pages are English for every language but German', () {
      expect(
        sitePageUri(site, SitePage.privacy, languageCode: 'fr'),
        Uri.parse('$site/en/privacy/'),
      );
      expect(
        sitePageUri('$site/', SitePage.legal, languageCode: 'de'),
        Uri.parse('$site/de/legal/'),
      );
    });
  });

  group('with the source code published', () {
    const address = 'https://code.example.org/rurana';

    Future<FakeExternalLinkOpener> pumpAbout(
      WidgetTester tester, {
      bool opens = true,
    }) async {
      final opener = FakeExternalLinkOpener(succeeds: opens);
      usePhoneSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appVersionProvider.overrideWithValue(testAppVersion),
            externalLinkOpenerProvider.overrideWithValue(opener),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: appSupportedLocales,
            home: AboutPage(sourceCode: address),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text(en.aboutSourceCodeOpen));
      return opener;
    }

    testWidgets('the page links to it', (tester) async {
      final opener = await pumpAbout(tester);

      expect(find.text(en.aboutSourceCodeLater), findsNothing);
      expect(find.text(address), findsOneWidget);
      await tester.tap(find.text(en.aboutSourceCodeOpen));
      await tester.pumpAndSettle();

      expect(opener.opened, [Uri.parse(address)]);
      expect(find.text(en.legalOpenFailed), findsNothing);
    });

    testWidgets('a link that does not open says so', (tester) async {
      await pumpAbout(tester, opens: false);

      await tester.tap(find.text(en.aboutSourceCodeOpen));
      await tester.pumpAndSettle();

      expect(find.text(en.legalOpenFailed), findsOneWidget);
    });
  });
}
