import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/legal.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/links/external_link_opener.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/about/presentation/about_page.dart';
import 'package:vikunja_mobile/features/about/presentation/support_details_page.dart';
import 'package:vikunja_mobile/features/home/application/app_version.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fakes.dart';
import '../../helpers/guest_app.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/test_database.dart';

void main() {
  Finder aboutList() => find
      .descendant(of: find.byType(AboutPage), matching: find.byType(Scrollable))
      .first;

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 100, scrollable: aboutList());
    await tester.pumpAndSettle();
  }

  final unofficial = find.textContaining(
    RegExp(
      'unofficial|affiliated|inoffiziell|Vikunja-Projekt',
      caseSensitive: false,
    ),
  );

  Future<void> expectNotices(WidgetTester tester) async {
    expect(find.byType(AboutPage), findsOneWidget);
    expect(find.text('About the app'), findsOneWidget);
    expect(find.text('Vikunja'), findsOneWidget);
    expect(find.text(en.aboutVersion('1.0.0', '42')), findsOneWidget);
    expect(find.text(copyrightNotice), findsOneWidget);
    expect(unofficial, findsNothing);
    for (final text in [
      en.aboutSupport,
      en.supportDetailsTitle,
      en.aboutPrivacyPolicy,
      en.aboutLegalNotice,
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
      expect(unofficial, findsNothing);
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

  Future<void> openSupportDetails(WidgetTester tester) async {
    await scrollTo(tester, find.text(en.supportDetailsTitle));
    await tester.tap(find.text(en.supportDetailsTitle));
    await tester.pumpAndSettle();
  }

  Finder detailsText() => find.textContaining('Support details\nCreated:');

  testWidgets('signed out, Support details opens its page from About, and '
      'back returns to About', (tester) async {
    usePhoneSurface(tester);
    await pumpVikunjaApp(tester);
    unawaited(
      containerOf(tester).read(appRouterProvider).push(AppRoutes.about),
    );
    await tester.pumpAndSettle();

    await openSupportDetails(tester);

    expect(find.byType(SupportDetailsPage), findsOneWidget);
    expect(
      tester.widget<Text>(detailsText()).data,
      endsWith('\nAccounts: none'),
    );
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(SupportDetailsPage), findsNothing);
    expect(find.byType(AboutPage), findsOneWidget);
  });

  testWidgets('a link-share guest opens the support details from About', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await pumpGuestApp(
      tester,
      auth: AuthFakes(),
      data: SyncFakes(),
      overrides: [
        appDatabaseProvider.overrideWith((ref, accountId) => testDatabase()),
      ],
    );
    await openFromAccountTab(tester);

    await openSupportDetails(tester);

    expect(find.byType(SupportDetailsPage), findsOneWidget);
    expect(
      tester.widget<Text>(detailsText()).data,
      contains('\nAccount 1 (active)\nKind: guest\n'),
    );
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

  Future<MaterialLocalizations> openLicences(
    WidgetTester tester,
    AppLocalizations l10n,
  ) async {
    usePhoneSurface(tester);
    await pumpVikunjaApp(tester);
    unawaited(
      containerOf(tester).read(appRouterProvider).push(AppRoutes.about),
    );
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text(l10n.aboutLicences));
    await tester.tap(find.text(l10n.aboutLicences));
    // The licences load in the background, behind a progress indicator.
    await pumpFrames(tester, 5);
    return MaterialLocalizations.of(tester.element(find.byType(LicensePage)));
  }

  testWidgets('Licenses opens the licence page with the app named, in '
      "Flutter's own English", (tester) async {
    final pageLocalizations = await openLicences(tester, en);

    final page = tester.widget<LicensePage>(find.byType(LicensePage));
    expect(page.applicationName, 'Vikunja');
    expect(page.applicationVersion, en.aboutVersion('1.0.0', '42'));
    expect(page.applicationLegalese, copyrightNotice);
    expect(pageLocalizations.licensesPageTitle, 'Licenses');
    expect(pageLocalizations.licensesPackageDetailText(2), '2 licenses');
  });

  testWidgets("the licence page keeps Flutter's texts in German", (
    tester,
  ) async {
    useLocale(tester, const Locale('de'));

    final pageLocalizations = await openLicences(tester, de);

    expect(pageLocalizations.licensesPageTitle, 'Lizenzen');
  });

  group('the support page, the privacy policy and the legal notice', () {
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
            home: AboutPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return opener;
    }

    Future<void> openRows(WidgetTester tester, List<String> titles) async {
      for (final title in titles) {
        await scrollTo(tester, find.text(title));
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('open in English', (tester) async {
      final opener = await pumpAbout(tester);

      expect(find.text(en.aboutWebsiteHeading), findsOneWidget);
      await openRows(tester, [
        en.aboutSupport,
        en.aboutPrivacyPolicy,
        en.aboutLegalNotice,
      ]);

      expect(opener.opened, [
        Uri.parse('https://coderoftime.dev/rurana/support/'),
        Uri.parse('https://coderoftime.dev/rurana/privacy/'),
        Uri.parse('https://coderoftime.dev/impressum/#en'),
      ]);
      expect(find.text(en.legalOpenFailed), findsNothing);
    });

    testWidgets('open in German when the app is in German', (tester) async {
      useLocale(tester, const Locale('de'));
      final opener = await pumpAbout(tester);

      expect(find.text(de.aboutWebsiteHeading), findsOneWidget);
      expect(find.text('Hilfe und Fehler melden'), findsOneWidget);
      await openRows(tester, [
        de.aboutSupport,
        de.aboutPrivacyPolicy,
        de.aboutLegalNotice,
      ]);

      expect(opener.opened, [
        Uri.parse('https://coderoftime.dev/de/rurana/support/'),
        Uri.parse('https://coderoftime.dev/rurana/privacy/#de'),
        Uri.parse('https://coderoftime.dev/impressum/#de'),
      ]);
    });

    testWidgets('in German, the page is about the app and no line calls it '
        'unofficial', (tester) async {
      useLocale(tester, const Locale('de'));
      await pumpAbout(tester);

      expect(find.text('Über die App'), findsOneWidget);
      expect(unofficial, findsNothing);
      for (final text in [
        de.aboutLicence,
        de.aboutLicences,
        de.aboutNameAndLogo,
      ]) {
        await scrollTo(tester, find.text(text));
        expect(unofficial, findsNothing);
      }
    });

    testWidgets('a link that does not open says so', (tester) async {
      await pumpAbout(tester, opens: false);

      await openRows(tester, [en.aboutPrivacyPolicy]);

      expect(find.text(en.legalOpenFailed), findsOneWidget);
    });

    test('are English for every language but German', () {
      for (final languageCode in ['en', 'fr', 'nl']) {
        expect(
          WebsitePage.support.uri(languageCode: languageCode),
          Uri.parse('https://coderoftime.dev/rurana/support/'),
        );
        expect(
          WebsitePage.privacy.uri(languageCode: languageCode),
          Uri.parse('https://coderoftime.dev/rurana/privacy/'),
        );
        expect(
          WebsitePage.legalNotice.uri(languageCode: languageCode),
          Uri.parse('https://coderoftime.dev/impressum/#en'),
        );
      }
    });
  });

  group('with the source code published', () {
    const address = 'https://code.example.org/vikunja-app';

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
