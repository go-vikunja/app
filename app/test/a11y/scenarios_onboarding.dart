import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/connection/application/certificate_checks.dart';
import 'package:vikunja_mobile/features/connection/presentation/certificate_page.dart';
import 'package:vikunja_mobile/features/connection/presentation/client_certificate_page.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_navigation.dart';
import 'package:vikunja_mobile/features/connection/presentation/headers_page.dart';
import 'package:vikunja_mobile/features/notifications/presentation/notification_setup_screen.dart';
import 'package:vikunja_mobile/features/onboarding/application/current_server.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_failure_card.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connection_error_card.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_overview_screen.dart';
import 'package:vikunja_mobile/features/sync/presentation/first_sync_screen.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/connection_fakes.dart';
import '../helpers/fakes.dart';
import '../helpers/notification_ui_fakes.dart';
import '../helpers/pump_app.dart';
import '../helpers/server_connections.dart';
import '../helpers/tls_fixtures.dart';
import 'sweep_data.dart';
import 'sweep_harness.dart';

final _secure = OriginKey.of(Uri.parse('https://vikunja.example.com'));
final _plain = OriginKey.of(Uri.parse('http://192.168.1.20:3456'));

Finder _connectionOverview() => find.byWidgetPredicate(
  (widget) => widget.runtimeType.toString() == '_ConnectionOverview',
);

/// One address's connection settings, signed out, with a certificate, a
/// client certificate and headers stored for the https one.
SweepScenario _connection(
  String variant,
  OriginKey origin,
  ScreenFinder expectScreen, {
  ConnectionEditor? editor,
}) => SweepScenario.route(
  AppRoutes.connection,
  variant: variant,
  setUp: (tester, _) async {
    final auth = AuthFakes();
    final profiles = profilesOver(auth);
    await profiles.consentToCleartext(_plain);
    await profiles.trustCertificate(
      _secure,
      tlsFixtureCertificate('selfsigned.pem'),
    );
    await profiles.setClientCertificate(
      _secure,
      fileName: 'phone.p12',
      bytes: tlsFixture('client.p12'),
      password: tlsFixturePassword,
    );
    await profiles.setHeaders(_secure, {'CF-Access-Client-Id': 'dummy-id'});
    await pumpVikunjaApp(
      tester,
      auth: auth,
      overrides: [
        FakeCertificateChecks(fetched: ProbedCertificate(renewedCertificate))
            .providerOverride,
      ],
    );
  },
  navigate: (tester, _) async =>
      pushTo(tester, AppRoutes.connectionFor(origin, editor: editor)),
  expectScreen: expectScreen,
);

Future<void> _submitAddress(WidgetTester tester, String address) async {
  await tester.enterText(find.byType(TextFormField), address);
  await tester.testTextInput.receiveAction(TextInputAction.go);
}

/// The way in: connecting to a server, its overview, the connection
/// settings, the first sync, the notification setup, and adding another
/// account over the shell.
final List<SweepScenario> onboardingRouteScenarios = [
  SweepScenario.route(
    AppRoutes.connect,
    setUp: (tester, _) => pumpVikunjaApp(tester),
    expectScreen: (_) => find.byType(ConnectServerScreen),
  ),
  SweepScenario.route(
    AppRoutes.serverOverview,
    setUp: (tester, _) => pumpServerOverview(tester, fullServer270()),
    expectScreen: (_) => find.byType(ServerOverviewScreen),
  ),
  _connection('https', _secure, (_) => _connectionOverview()),
  _connection('http', _plain, (_) => _connectionOverview()),
  _connection(
    'headers',
    _secure,
    (_) => find.byType(HeadersPage),
    editor: ConnectionEditor.headers,
  ),
  _connection(
    'certificate',
    _secure,
    (_) => find.byType(CertificatePage),
    editor: ConnectionEditor.certificate,
  ),
  _connection(
    'clientCertificate',
    _secure,
    (_) => find.byType(ClientCertificatePage),
    editor: ConnectionEditor.clientCertificate,
  ),
  SweepScenario.route(
    AppRoutes.firstSync,
    settle: false,
    setUp: (tester, _) async {
      final data = sweepData(status: const SyncNeverRun());
      data.engine.onEnsureInitialSync = () => Completer<void>().future;
      await pumpSweepApp(tester, data: data, settle: false);
    },
    expectScreen: (_) => find.byType(FirstSyncScreen),
  ),
  SweepScenario.route(
    AppRoutes.notificationsSetup,
    setUp: (tester, _) async {
      final auth = AuthFakes(notificationsOnboarded: false);
      await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      );
      await pumpVikunjaApp(
        tester,
        auth: auth,
        sync: sweepData(),
        notifications: NotificationFakes(
          capabilities: const NotificationCapabilities(
            permission: NotificationPermission.notAsked,
            exactAlarms: false,
          ),
        ),
      );
    },
    expectScreen: (_) => find.byType(NotificationSetupScreen),
  ),
  SweepScenario.route(
    AppRoutes.addAccount,
    setUp: (tester, _) => pumpSweepApp(tester),
    navigate: (tester, _) async => pushTo(tester, AppRoutes.addAccount),
    expectScreen: (_) => find.byType(ConnectServerScreen),
  ),
  SweepScenario.route(
    AppRoutes.addAccountServer,
    setUp: (tester, _) => pumpSweepApp(tester),
    navigate: (tester, _) async {
      containerOf(tester)
          .read(currentServerProvider.notifier)
          .select(accountPagesServer270());
      pushTo(tester, AppRoutes.addAccount);
      await tester.pumpAndSettle();
      pushTo(tester, AppRoutes.addAccountServer);
    },
    expectScreen: (_) => find.byType(ServerOverviewScreen),
  ),
];

/// The connect screen's failure, its question before an unencrypted
/// connection, the hint before the browser opens, and a failed sign-in.
final List<SweepScenario> onboardingStateScenarios = [
  SweepScenario(
    kind: SweepKind.state,
    name: 'connect failure',
    route: AppRoutes.connect,
    setUp: (tester, _) => pumpVikunjaApp(
      tester,
      connector: FakeServerConnector.failing(
        BehindLoginProxy(Uri.parse('https://tasks.example.org')),
      ),
    ),
    navigate: (tester, _) => _submitAddress(tester, 'tasks.example.org'),
    expectScreen: (_) => find.byType(ConnectFailureCard),
  ),
  SweepScenario(
    kind: SweepKind.state,
    name: 'connect insecure question',
    route: AppRoutes.connect,
    setUp: (tester, _) => pumpVikunjaApp(
      tester,
      connector: FakeServerConnector.succeeding(insecureServer()),
    ),
    navigate: (tester, _) => _submitAddress(tester, '192.168.1.20:3456'),
    expectScreen: (_) => alertDialog,
  ),
  SweepScenario(
    kind: SweepKind.state,
    name: 'browser hint',
    route: AppRoutes.serverOverview,
    setUp: (tester, _) async {
      final auth = AuthFakes();
      final server = accountPagesServer270(
        frontendUrl: Uri.parse('https://web.example.org/'),
      );
      final profiles = profilesOver(auth);
      await profiles.setHeaders(OriginKey.of(server.rootUri), {
        'X-Gate-Token': 'dummy',
      });
      await profiles.trustCertificate(
        OriginKey.of(Uri.parse('https://web.example.org/')),
        tlsFixtureCertificate('selfsigned.pem'),
      );
      await pumpServerOverview(tester, server, auth: auth);
    },
    navigate: _tapSignIn,
    expectScreen: (_) => alertDialog,
  ),
  SweepScenario(
    kind: SweepKind.state,
    name: 'sign-in failure',
    route: AppRoutes.serverOverview,
    setUp: (tester, _) async {
      final auth = AuthFakes();
      auth.tokenGateway.onExchange = (_) async =>
          throw const RateLimited(retryAfter: Duration(minutes: 3));
      await pumpServerOverview(tester, fullServer270(), auth: auth);
    },
    navigate: _tapSignIn,
    expectScreen: (_) => find.byType(ConnectionErrorCard),
  ),
];

Future<void> _tapSignIn(WidgetTester tester, AppLocalizations _) async {
  final signIn = find.byType(FilledButton);
  await tester.ensureVisible(signIn);
  await tester.pumpAndSettle();
  await tester.tap(signIn);
}
