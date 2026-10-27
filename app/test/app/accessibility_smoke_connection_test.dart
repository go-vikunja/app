import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/features/connection/application/certificate_checks.dart';
import 'package:vikunja_mobile/features/connection/presentation/certificate_page.dart';
import 'package:vikunja_mobile/features/connection/presentation/client_certificate_page.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_navigation.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_page.dart';
import 'package:vikunja_mobile/features/connection/presentation/headers_page.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_overview_screen.dart';

import '../helpers/attachment_picker_fake.dart';
import '../helpers/auth_fakes.dart';
import '../helpers/connection_fakes.dart';
import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';
import '../helpers/server_connections.dart';
import '../helpers/tls_fixtures.dart';

// The connection settings at 200 % text in dark mode on a small phone, in
// English and German. Layout overflows are reported as test failures, so
// reaching the end of each scenario without an exception is the assertion.
void main() {
  const smallPhone = Size(320, 640);
  const locales = [Locale('en'), Locale('de')];
  final secure = OriginKey.of(Uri.parse('https://vikunja.example.com'));
  final plain = OriginKey.of(Uri.parse('http://192.168.1.20:3456'));

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
    for (var i = 0; i < 120 && position.extentAfter > 0; i++) {
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(position.extentAfter, 0);
  }

  Future<void> bringIntoView(
    WidgetTester tester,
    Type page,
    Finder finder,
  ) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: scrollableOf(page),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, String location) async {
    unawaited(containerOf(tester).read(appRouterProvider).push(location));
    await tester.pumpAndSettle();
  }

  for (final locale in locales) {
    final code = locale.languageCode;

    testWidgets('the connection screen of an https address with everything '
        'stored and a changed certificate at 200 % in dark mode ($code)', (
      tester,
    ) async {
      useWorstCase(tester, locale);
      final auth = AuthFakes();
      final profiles = profilesOver(auth);
      await profiles.trustCertificate(
        secure,
        tlsFixtureCertificate('selfsigned.pem'),
      );
      await profiles.recordPinMismatch(secure, renewedCertificate);
      await profiles.setClientCertificate(
        secure,
        fileName: 'a-rather-long-device-certificate-name.p12',
        bytes: tlsFixture('client.p12'),
        password: tlsFixturePassword,
      );
      await profiles.setHeaders(secure, {
        'CF-Access-Client-Id': 'dummy-id',
        'CF-Access-Client-Secret': 'dummy-secret',
      });
      await pumpVikunjaApp(tester, auth: auth);
      await open(tester, AppRoutes.connectionFor(secure));

      expect(find.byType(ConnectionPage), findsOneWidget);
      await scrollToEnd(tester, ConnectionPage);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the connection screen of an http address, unreadable '
        'settings and the reset question at 200 % in dark mode ($code)', (
      tester,
    ) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final auth = AuthFakes();
      await profilesOver(auth).consentToCleartext(plain);
      await pumpVikunjaApp(tester, auth: auth);
      await open(tester, AppRoutes.connectionFor(plain));
      await bringIntoView(
        tester,
        ConnectionPage,
        find.text(l10n.connectionCleartextRevoke),
      );
      await tester.tap(find.text(l10n.connectionCleartextRevoke));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      await scrollToEnd(tester, ConnectionPage);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the certificate screen with a CA outcome, and the review, '
        'at 200 % in dark mode ($code)', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final auth = AuthFakes();
      final checks = FakeCertificateChecks(
        fetched: ProbedCertificate(renewedCertificate),
      );
      final picker = FakeAttachmentPicker()..tooLargeFiles = ['huge.pem'];
      await profilesOver(auth).trustCaCertificate(
        secure,
        fileName: 'ca.pem',
        pem: tlsFixtureText('ca.pem'),
      );
      await pumpVikunjaApp(
        tester,
        auth: auth,
        overrides: [checks.providerOverride, picker.providerOverride],
      );
      await open(
        tester,
        AppRoutes.connectionFor(secure, editor: ConnectionEditor.certificate),
      );
      await bringIntoView(
        tester,
        CertificatePage,
        find.text(l10n.connectionUseCa),
      );
      await tester.tap(find.text(l10n.connectionUseCa));
      await tester.pumpAndSettle();
      expect(find.text(l10n.connectionFileTooLarge), findsOneWidget);
      await scrollToEnd(tester, CertificatePage);
      expect(tester.takeException(), isNull);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final profiles = profilesOver(auth);
      await profiles.trustCertificate(
        secure,
        tlsFixtureCertificate('selfsigned.pem'),
      );
      await profiles.recordPinMismatch(secure, thirdCertificate);
      await open(
        tester,
        AppRoutes.connectionFor(secure, editor: ConnectionEditor.certificate),
      );
      expect(find.text(l10n.connectionReviewTitle), findsOneWidget);
      await scrollToEnd(tester, CertificatePage);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the headers editor with refused entries, and the client '
        'certificate import, at 200 % in dark mode ($code)', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      await pumpVikunjaApp(tester, auth: AuthFakes());
      await open(
        tester,
        AppRoutes.connectionFor(secure, editor: ConnectionEditor.headers),
      );
      await bringIntoView(
        tester,
        HeadersPage,
        find.text(l10n.connectionHeaderPresetCustom),
      );
      await tester.tap(find.text(l10n.connectionHeaderPresetCustom));
      await tester.pumpAndSettle();
      await bringIntoView(tester, HeadersPage, find.text(l10n.connectionSave));
      await tester.tap(find.text(l10n.connectionSave));
      await tester.pumpAndSettle();
      await scrollToEnd(tester, HeadersPage);
      expect(tester.takeException(), isNull);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await open(
        tester,
        AppRoutes.connectionFor(
          secure,
          editor: ConnectionEditor.clientCertificate,
        ),
      );
      await bringIntoView(
        tester,
        ClientCertificatePage,
        find.text(l10n.connectionSave),
      );
      await tester.tap(find.text(l10n.connectionSave));
      await tester.pumpAndSettle();
      await scrollToEnd(tester, ClientCertificatePage);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the connect screen with a certificate failure, its fix and '
        'the connection options at 200 % in dark mode ($code)', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final auth = AuthFakes();
      await profilesOver(auth).trustCertificate(
        OriginKey.of(Uri.parse('https://vikunja.example.com:3456')),
        tlsFixtureCertificate('selfsigned.pem'),
      );
      await pumpVikunjaApp(
        tester,
        auth: auth,
        connector: FakeServerConnector.failing(
          TlsFailure(
            Uri.parse('https://vikunja.example.com:3456'),
            clientCertificateRefused: true,
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField),
        'https://vikunja.example.com:3456',
      );
      await tester.pumpAndSettle();
      await bringIntoView(
        tester,
        ConnectServerScreen,
        find.text(l10n.connectContinue),
      );
      await tester.tap(find.text(l10n.connectContinue));
      await tester.pumpAndSettle();

      expect(find.text(l10n.connectionAddClientCertificate), findsOneWidget);
      await scrollToEnd(tester, ConnectServerScreen);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the sign-out of the last account on a server with its '
        'settings, and the browser hint, at 200 % in dark mode ($code)', (
      tester,
    ) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final auth = AuthFakes();
      final profiles = profilesOver(auth);
      final server = fullServer270();
      final origin = OriginKey.of(server.rootUri);
      await profiles.trustCertificate(
        origin,
        tlsFixtureCertificate('selfsigned.pem'),
      );
      await profiles.setHeaders(origin, {'X-Gate-Token': 'dummy'});
      await pumpSignedInApp(tester, auth: auth);
      await openTab(tester, l10n.tabAccount);
      await bringIntoView(tester, AccountTab, find.text(l10n.homeSignOut));
      await tester.tap(find.text(l10n.homeSignOut));
      await tester.pumpAndSettle();
      expect(find.text(l10n.connectionForgetCheckbox), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the browser hint with the pinned fingerprint at 200 % in '
        'dark mode ($code)', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final auth = AuthFakes();
      final server = accountPagesServer270(
        frontendUrl: Uri.parse('https://web.example.org/'),
      );
      await profilesOver(auth)
          .setHeaders(OriginKey.of(server.rootUri), {'X-Gate-Token': 'dummy'});
      await profilesOver(auth).trustCertificate(
        OriginKey.of(Uri.parse('https://web.example.org/')),
        tlsFixtureCertificate('selfsigned.pem'),
      );
      await pumpServerOverview(tester, server, auth: auth);
      await bringIntoView(
        tester,
        ServerOverviewScreen,
        find.text(l10n.continueToSignIn),
      );
      await tester.tap(find.text(l10n.continueToSignIn));
      await tester.pumpAndSettle();

      expect(find.text(l10n.connectionBrowserHintTitle), findsOneWidget);
      expect(find.text(l10n.connectionBrowserHintPinned), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
