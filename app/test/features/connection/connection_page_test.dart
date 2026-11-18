import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/network/network_profile_providers.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/connection/application/certificate_checks.dart';
import 'package:vikunja_mobile/features/connection/presentation/certificate_page.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_page.dart';
import 'package:vikunja_mobile/features/onboarding/application/current_server.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_overview_screen.dart';
import 'package:vikunja_mobile/features/sync/presentation/first_sync_screen.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/connection_fakes.dart';
import '../../helpers/fakes.dart';
import '../../helpers/guest_entry_fakes.dart';
import '../../helpers/guest_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/tls_fixtures.dart';

void main() {
  final secure = OriginKey.of(Uri.parse('https://vikunja.example.com'));
  final plain = OriginKey.of(Uri.parse('http://192.168.1.20:3456'));
  late AuthFakes auth;
  late FakeCertificateChecks checks;

  setUp(() {
    auth = AuthFakes();
    checks = FakeCertificateChecks();
  });

  String location(WidgetTester tester) =>
      containerOf(tester)
          .read(appRouterProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .toString();

  Future<void> open(WidgetTester tester, String location) async {
    unawaited(containerOf(tester).read(appRouterProvider).push(location));
    await tester.pumpAndSettle();
  }

  Future<void> pumpSignedOut(WidgetTester tester) async {
    usePhoneSurface(tester, logicalSize: const Size(360, 1400));
    await pumpVikunjaApp(
      tester,
      auth: auth,
      overrides: [checks.providerOverride],
    );
  }

  group('the route', () {
    testWidgets('stays open while signed out', (tester) async {
      await pumpSignedOut(tester);
      await open(tester, AppRoutes.connectionFor(secure));

      expect(find.byType(ConnectionPage), findsOneWidget);
      expect(find.text(en.connectionOptionsFor('$secure')), findsOneWidget);
    });

    testWidgets('stays open before the first sync', (tester) async {
      final data = SyncFakes(status: const SyncNeverRun());
      data.engine.onEnsureInitialSync = () => Completer<void>().future;
      await pumpSignedInApp(tester, sync: data, auth: auth, settle: false);
      await pumpUntil(tester, find.byType(FirstSyncScreen));

      unawaited(
        containerOf(tester)
            .read(appRouterProvider)
            .push(AppRoutes.connectionFor(secure)),
      );
      await pumpUntil(tester, find.byType(ConnectionPage));
      await pumpFrames(tester, 3);

      expect(find.byType(ConnectionPage), findsOneWidget);
      expect(find.byType(FirstSyncScreen, skipOffstage: false), findsOneWidget);
    });

    testWidgets('stays open signed in and returns to where it came from', (
      tester,
    ) async {
      await pumpSignedInApp(tester, auth: auth);
      await openTab(tester, en.tabAccount);
      await open(tester, AppRoutes.connectionFor(secure));

      expect(find.byType(ConnectionPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(location(tester), AppRoutes.account);
    });

    testWidgets('an address that does not parse closes the page at once', (
      tester,
    ) async {
      await pumpSignedOut(tester);
      await open(tester, '${AppRoutes.connection}?origin=https://x.example');

      expect(find.byType(ConnectionPage), findsNothing);
      expect(find.byType(ConnectServerScreen), findsOneWidget);
    });
  });

  group('an https address', () {
    testWidgets('without settings offers the certificate check, a client '
        'certificate and headers; a trusted certificate then shows', (
      tester,
    ) async {
      await pumpSignedOut(tester);
      await open(tester, AppRoutes.connectionFor(secure));

      expect(find.text(en.connectionDeviceTrust), findsOneWidget);
      expect(find.text(en.connectionClientCertificateNone), findsOneWidget);
      expect(find.text(en.connectionHeadersNone), findsOneWidget);
      expect(find.text(en.connectionForget), findsNothing);
      expect(find.text(en.connectionCleartextHeading), findsNothing);

      await tester.tap(find.text(en.connectionCheckCertificate));
      await tester.pumpAndSettle();
      expect(find.byType(CertificatePage), findsOneWidget);
      expect(checks.fetches, [secure]);
      await tester.ensureVisible(find.text(en.connectionTrustCertificate));
      await tester.tap(find.text(en.connectionTrustCertificate));
      await tester.pumpAndSettle();

      expect(find.byType(CertificatePage), findsNothing);
      expect(find.text(en.connectionPinnedTitle), findsOneWidget);
      final profile = await profilesOver(auth).metadataFor(secure);
      expect(profile?.pin?.sha256, tlsFixtureSha256('selfsigned.pem'));
      expect(find.text(en.connectionForget), findsOneWidget);
    });

    testWidgets('a changed certificate shows a card that opens the review', (
      tester,
    ) async {
      final profiles = profilesOver(auth);
      await profiles.trustCertificate(
        secure,
        tlsFixtureCertificate('selfsigned.pem'),
      );
      await profiles.recordPinMismatch(secure, renewedCertificate);
      checks.fetched = ProbedCertificate(renewedCertificate);
      await pumpSignedOut(tester);
      await open(tester, AppRoutes.connectionFor(secure));

      expect(find.text(en.connectionMismatchTitle), findsOneWidget);
      await tester.tap(find.text(en.connectionMismatchReview));
      await tester.pumpAndSettle();

      expect(find.text(en.connectionReviewTitle), findsOneWidget);
    });

    testWidgets('stored headers show by name with hidden values, and Remove '
        'asks first', (tester) async {
      await profilesOver(auth).setHeaders(secure, {
        'CF-Access-Client-Id': 'dummy-id.access',
        'CF-Access-Client-Secret': 'dummy-secret-value',
      });
      await pumpSignedOut(tester);
      await open(tester, AppRoutes.connectionFor(secure));

      expect(find.text('CF-Access-Client-Id'), findsOneWidget);
      expect(find.text('CF-Access-Client-Secret'), findsOneWidget);
      expect(find.textContaining('dummy-secret-value'), findsNothing);
      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp(en.connectionHeaderValueHidden)),
        findsNWidgets(2),
      );
      semantics.dispose();

      await tester.tap(find.text(en.connectionRemove));
      await tester.pumpAndSettle();
      expect(find.text(en.connectionRemoveHeadersTitle), findsOneWidget);
      await tester.tap(find.text(en.connectionRemove).last);
      await tester.pumpAndSettle();

      expect(find.text('CF-Access-Client-Id'), findsNothing);
      expect(find.text(en.connectionHeadersNone), findsOneWidget);
      expect(await profilesOver(auth).metadataFor(secure), isNull);
    });

    testWidgets('Forget asks, then removes everything for the address', (
      tester,
    ) async {
      await profilesOver(auth)
          .trustCertificate(secure, tlsFixtureCertificate('selfsigned.pem'));
      await pumpSignedOut(tester);
      await open(tester, AppRoutes.connectionFor(secure));

      await tester.tap(find.text(en.connectionForget));
      await tester.pumpAndSettle();
      expect(
        find.text(en.connectionForgetBody(secure.authority)),
        findsOneWidget,
      );
      await tester.tap(find.text(en.connectionForgetConfirm));
      await tester.pumpAndSettle();

      expect(find.text(en.connectionDeviceTrust), findsOneWidget);
      expect(await profilesOver(auth).metadataFor(secure), isNull);
    });

    testWidgets('unreadable settings show only the notice and reset after '
        'the confirmation', (tester) async {
      auth.preferences.values[NetworkProfiles.storageKey] = '{not json';
      await pumpSignedOut(tester);
      await open(tester, AppRoutes.connectionFor(secure));

      expect(find.text(en.connectionProfileDamagedTitle), findsOneWidget);
      expect(find.text(en.connectionCheckCertificate), findsNothing);
      expect(find.text(en.connectionHeadersHeading), findsNothing);

      await tester.tap(find.text(en.connectionReset));
      await tester.pumpAndSettle();
      expect(find.text(en.connectionResetBody), findsOneWidget);
      await tester.tap(find.text(en.connectionResetConfirm));
      await tester.pumpAndSettle();

      expect(find.text(en.connectionProfileDamagedTitle), findsNothing);
      expect(find.text(en.connectionDeviceTrust), findsOneWidget);
    });

    testWidgets('settings not readable yet show the notice and Try again, '
        'without edits', (tester) async {
      usePhoneSurface(tester, logicalSize: const Size(360, 1400));
      await pumpVikunjaApp(
        tester,
        auth: auth,
        overrides: [
          checks.providerOverride,
          connectionProfileProvider(secure).overrideWith(
            (ref) => Stream.value(
              ConnectionProfileState(
                origin: secure,
                status: ConnectionProfileStatus.unavailable,
              ),
            ),
          ),
        ],
      );
      await open(tester, AppRoutes.connectionFor(secure));

      expect(find.text(en.connectionProfileLockedTitle), findsOneWidget);
      expect(find.text(en.retry), findsOneWidget);
      expect(find.text(en.connectionCheckCertificate), findsNothing);
      expect(find.text(en.connectionForget), findsNothing);
      await tester.tap(find.text(en.retry));
      await tester.pumpAndSettle();
      expect(find.text(en.connectionProfileLockedTitle), findsOneWidget);
    });
  });

  group('an http address', () {
    final httpsRoot = Uri.parse('https://192.168.1.20');

    /// Alice's account at [plain] unless [seed] stores others.
    Future<FakeServerConnector> pumpWithAccountThere(
      WidgetTester tester, {
      required bool httpsAnswers,
      Future<void> Function()? seed,
      SyncFakes? data,
      bool openPage = true,
    }) async {
      usePhoneSurface(tester, logicalSize: const Size(360, 1400));
      await profilesOver(auth).consentToCleartext(plain);
      if (seed != null) {
        await seed();
      } else {
        await auth.seedAccount(
          insecureServer(),
          tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
        );
      }
      final connector = FakeServerConnector(
        (input) async => httpsAnswers && input == '$httpsRoot'
            ? fullServer270(root: '$httpsRoot')
            : throw ServerUnreachable(Uri.parse(input)),
      );
      await pumpVikunjaApp(
        tester,
        auth: auth,
        sync: data ?? SyncFakes(),
        connector: connector,
        overrides: [checks.providerOverride, ...guestEntryOverrides()],
      );
      if (openPage) await open(tester, AppRoutes.connectionFor(plain));
      return connector;
    }

    String top(WidgetTester tester) =>
        containerOf(tester)
            .read(appRouterProvider)
            .routerDelegate
            .state
            .matchedLocation;

    List<String> accountIds(WidgetTester tester) => [
      for (final entry in containerOf(
        tester,
      ).read(accountsProvider).value!.accounts)
        entry.id,
    ];

    testWidgets('with an account there, offers https where the same server '
        'answers, and Use https adds the account at that address', (
      tester,
    ) async {
      final connector = await pumpWithAccountThere(tester, httpsAnswers: true);

      expect(connector.inputs, ['$httpsRoot']);
      expect(
        find.text(en.connectionHttpsAvailable('$httpsRoot')),
        findsOneWidget,
      );
      expect(find.text(en.connectionCleartextRevoke), findsOneWidget);

      await tester.tap(find.text(en.connectionUseHttps));
      await tester.pumpAndSettle();

      expect(connector.inputs, ['$httpsRoot', '$httpsRoot']);
      expect(
        tester.widget<ServerOverviewScreen>(find.byType(ServerOverviewScreen)),
        isA<ServerOverviewScreen>().having((s) => s.adding, 'adding', isTrue),
      );
      expect(
        containerOf(tester).read(currentServerProvider)?.rootUri,
        httpsRoot,
      );
    });

    testWidgets('once signed in over https, the app offers to remove the '
        'http account, and Remove does', (tester) async {
      const alice = User(id: 7, username: 'alice', name: 'Alice Example');
      auth.serveUser(alice, now: DateTime.now().toUtc());
      final httpsId = accountIdFor(httpsRoot, alice.id);
      final data = SyncFakes();
      data.accounts[httpsId] = AccountDataFakes(
        now: DateTime.now(),
        status: const SyncNeverRun(),
      );
      await pumpWithAccountThere(tester, httpsAnswers: true, data: data);
      final httpId = accountIds(tester).single;

      await tester.tap(find.text(en.connectionUseHttps));
      await tester.pumpAndSettle();
      expect(find.text(en.httpAccountRemoveTitle), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, en.continueToSignIn));
      await tester.pumpAndSettle();

      expect(accountIds(tester), [httpId, httpsId]);
      expect(find.text(en.httpAccountRemoveTitle), findsOneWidget);
      expect(
        find.textContaining(en.httpAccountRemoveReason('192.168.1.20')),
        findsOneWidget,
      );
      expect(
        find.textContaining(en.removeAccountDialogPendingChanges(1)),
        findsNothing,
      );
      await tester.tap(find.text(en.removeAccountDialogConfirm).last);
      await tester.pumpAndSettle();

      expect(accountIds(tester), [httpsId]);
      expect(find.text(en.httpAccountRemoveTitle), findsNothing);
    });

    testWidgets('Use HTTPS from the Add account screen returns to that '
        'screen with the https address', (tester) async {
      final connector = await pumpWithAccountThere(
        tester,
        httpsAnswers: true,
        openPage: false,
      );
      await open(tester, AppRoutes.addAccount);
      await open(tester, AppRoutes.connectionFor(plain));

      await tester.tap(find.text(en.connectionUseHttps));
      await tester.pumpAndSettle();

      expect(connector.inputs, ['$httpsRoot', '$httpsRoot']);
      expect(
        find.byType(ConnectServerScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byType(ServerOverviewScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byType(ConnectionPage, skipOffstage: false), findsNothing);
      expect(top(tester), AppRoutes.addAccountServer);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(top(tester), AppRoutes.addAccount);
      expect(find.text('$httpsRoot'), findsOneWidget);
    });

    testWidgets('a guest there gets no https offer', (tester) async {
      final connector = await pumpWithAccountThere(
        tester,
        httpsAnswers: true,
        seed: () => auth.seedGuest(
          insecureServer(),
          token: issueLinkShareToken(issuedAt: DateTime.now().toUtc()),
        ),
      );

      expect(connector.inputs, isEmpty);
      expect(find.text(en.connectionUseHttps), findsNothing);
      expect(find.text(en.connectionCleartextRevoke), findsOneWidget);
    });

    testWidgets('offers no https once the same user is signed in there too', (
      tester,
    ) async {
      final connector = await pumpWithAccountThere(
        tester,
        httpsAnswers: true,
        seed: () async {
          final tokens = issueTokens(issuedAt: DateTime.now().toUtc());
          await auth.seedAccount(
            fullServer270(root: '$httpsRoot'),
            tokens: tokens,
            activate: false,
          );
          await auth.seedAccount(insecureServer(), tokens: tokens);
        },
      );

      expect(connector.inputs, isEmpty);
      expect(find.text(en.connectionUseHttps), findsNothing);
      expect(find.text(en.connectionCleartextRevoke), findsOneWidget);
    });

    testWidgets('offers no https where it does not answer, nor without an '
        'account there', (tester) async {
      final connector = await pumpWithAccountThere(tester, httpsAnswers: false);

      expect(connector.inputs, ['$httpsRoot']);
      expect(find.text(en.connectionUseHttps), findsNothing);
      expect(find.text(en.connectionCleartextRevoke), findsOneWidget);

      await open(
        tester,
        AppRoutes.connectionFor(
          OriginKey.of(Uri.parse('http://192.168.1.30:3456')),
        ),
      );
      expect(connector.inputs, ['$httpsRoot']);
      expect(find.text(en.connectionUseHttps), findsNothing);
    });

    testWidgets('offers to allow unencrypted connections with the existing '
        'question, and only then headers', (tester) async {
      await pumpSignedOut(tester);
      await open(tester, AppRoutes.connectionFor(plain));

      expect(find.text(en.connectionCleartextNotAllowed), findsOneWidget);
      expect(find.text(en.connectionHeadersNeedCleartext), findsOneWidget);
      expect(find.text(en.connectionServerCertificateHeading), findsNothing);
      expect(find.text(en.connectionClientCertificateHeading), findsNothing);

      await tester.tap(find.text(en.connectionCleartextAllow));
      await tester.pumpAndSettle();
      expect(find.text(en.insecureDialogTitle), findsOneWidget);
      await tester.tap(find.text(en.insecureDialogContinue));
      await tester.pumpAndSettle();

      expect(
        (await profilesOver(auth).metadataFor(plain))?.hasCleartextConsent,
        isTrue,
      );
      expect(find.text(en.connectionCleartextRevoke), findsOneWidget);
      expect(find.text(en.connectionHeadersNone), findsOneWidget);
      expect(find.text(en.connectionHeadersUnencrypted), findsOneWidget);
    });

    testWidgets('Revoke explains that requests will fail, then removes the '
        'consent', (tester) async {
      await profilesOver(auth).consentToCleartext(plain);
      await pumpSignedOut(tester);
      await open(tester, AppRoutes.connectionFor(plain));

      await tester.tap(find.text(en.connectionCleartextRevoke));
      await tester.pumpAndSettle();
      expect(
        find.text(en.connectionCleartextRevokeBody(plain.authority)),
        findsOneWidget,
      );
      await tester.tap(find.text(en.connectionCleartextRevoke).last);
      await tester.pumpAndSettle();

      expect(find.text(en.connectionCleartextNotAllowed), findsOneWidget);
      expect(
        (await profilesOver(auth).metadataFor(plain))?.hasCleartextConsent ??
            false,
        isFalse,
      );
    });

    testWidgets('after Revoke, stored headers stay listed as not sent, and '
        'Remove deletes them', (tester) async {
      final profiles = profilesOver(auth);
      await profiles.consentToCleartext(plain);
      await profiles.setHeaders(plain, {'X-Token': 'dummy-http-header'});
      await profiles.revokeCleartext(plain);
      await pumpSignedOut(tester);
      await open(tester, AppRoutes.connectionFor(plain));

      expect(find.text('X-Token'), findsOneWidget);
      expect(find.text(en.connectionHeadersHeldBack), findsOneWidget);
      expect(find.text(en.connectionHeadersNeedCleartext), findsNothing);
      expect(find.text(en.connectionEditHeaders), findsNothing);

      await tester.ensureVisible(find.text(en.connectionRemove));
      await tester.tap(find.text(en.connectionRemove));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.connectionRemove).last);
      await tester.pumpAndSettle();

      expect(await profilesOver(auth).metadataFor(plain), isNull);
      expect(find.text('X-Token'), findsNothing);
      expect(find.text(en.connectionHeadersNeedCleartext), findsOneWidget);
    });
  });
}
