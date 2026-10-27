import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/link_share_account_id.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/features/connection/presentation/certificate_page.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_page.dart';
import 'package:vikunja_mobile/features/connection/presentation/headers_page.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connection_options_button.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_overview_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';

import '../../../helpers/auth_fakes.dart';
import '../../../helpers/connection_fakes.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/guest_entry_fakes.dart';
import '../../../helpers/guest_fakes.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/sample_data.dart';
import '../../../helpers/server_connections.dart';
import '../../../helpers/sync_fakes.dart';
import '../../../helpers/tls_fixtures.dart';

final Finder _addressField = find.byType(TextFormField);
final Finder _continueButton = find.widgetWithText(
  FilledButton,
  en.connectContinue,
);

void main() {
  final root = Uri.parse('https://vikunja.example.com');
  final origin = OriginKey.of(root);
  late AuthFakes auth;
  late SyncFakes data;
  late FakeServerConnector connector;
  late FakeCertificateChecks checks;

  setUp(() {
    auth = AuthFakes();
    data = SyncFakes();
    data.projects.all = [sampleProject(id: 1378, title: 'Garden')];
    connector = FakeServerConnector();
    checks = FakeCertificateChecks();
  });

  Future<void> pump(WidgetTester tester) async {
    usePhoneSurface(tester, logicalSize: const Size(400, 1400));
    await pumpVikunjaApp(
      tester,
      connector: connector,
      auth: auth,
      sync: data,
      overrides: [checks.providerOverride, ...guestEntryOverrides()],
    );
  }

  Future<void> submit(WidgetTester tester, String address) async {
    await tester.enterText(_addressField, address);
    await tester.tap(_continueButton);
    await tester.pumpAndSettle();
  }

  /// Fails with [failure] until [fixed] is set.
  void failUntilFixed(Exception failure, ServerConnection connection) {
    var fixed = false;
    connector.handler = (_) async {
      if (!fixed) {
        fixed = true;
        throw failure;
      }
      return connection;
    };
  }

  group('a failure the connection settings fix offers its fix', () {
    final cases = <String, (Object, String?)>{
      'certificate rejected': (
        TlsFailure(root, certificateRejected: true),
        en.connectionViewCertificate,
      ),
      'login proxy': (BehindLoginProxy(root), en.connectionAddHeaders),
      'not Vikunja with 403': (
        NotAVikunjaServer(root, statusCode: 403),
        en.connectionAddHeaders,
      ),
      'not Vikunja with 404': (NotAVikunjaServer(root, statusCode: 404), null),
      'client certificate': (
        TlsFailure(root, clientCertificateRefused: true),
        en.connectionAddClientCertificate,
      ),
      'incomplete settings': (
        ConnectionSettingsFailure(
          root,
          problem: ConnectionSettingsProblem.incomplete,
        ),
        en.connectionOpenSettings,
      ),
      'unencrypted not allowed': (
        ConnectionSettingsFailure(
          root,
          problem: ConnectionSettingsProblem.cleartextBlocked,
        ),
        en.connectionOpenSettings,
      ),
      'settings not readable yet': (
        ConnectionSettingsFailure(
          root,
          problem: ConnectionSettingsProblem.locked,
        ),
        en.retry,
      ),
      'damaged settings': (
        ConnectionSettingsFailure(
          root,
          problem: ConnectionSettingsProblem.damaged,
        ),
        en.connectionReset,
      ),
      'unreachable': (ServerUnreachable(root), null),
    };
    for (final MapEntry(key: name, value: (failure, action)) in cases.entries) {
      testWidgets(name, (tester) async {
        connector = FakeServerConnector.failing(failure);
        await pump(tester);
        await submit(tester, 'vikunja.example.com');

        final fixes = [
          en.connectionViewCertificate,
          en.connectionAddHeaders,
          en.connectionAddClientCertificate,
          en.connectionReplaceClientCertificate,
          en.connectionOpenSettings,
          en.retry,
          en.connectionReset,
        ];
        for (final label in fixes) {
          expect(
            find.widgetWithText(TextButton, label),
            label == action ? findsOneWidget : findsNothing,
            reason: label,
          );
        }
        // The fallback when nothing is classified.
        expect(find.byType(ConnectionOptionsButton), findsOneWidget);
      });
    }
  });

  testWidgets('a client-certificate failure says whether one is stored', (
    tester,
  ) async {
    connector = FakeServerConnector.failing(
      TlsFailure(root, clientCertificateRefused: true),
    );
    await pump(tester);
    await submit(tester, 'vikunja.example.com');
    expect(
      find.text(
        en.connectionClientCertificateNeededExplanation(origin.authority),
      ),
      findsOneWidget,
    );

    await profilesOver(auth).setClientCertificate(
      origin,
      fileName: 'client.p12',
      bytes: tlsFixture('client.p12'),
      password: tlsFixturePassword,
    );
    await submit(tester, 'vikunja.example.com');

    expect(
      find.text(
        en.connectionClientCertificateRefusedExplanation(origin.authority),
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextButton, en.connectionReplaceClientCertificate),
      findsOneWidget,
    );
  });

  testWidgets('trusting the certificate connects again without typing', (
    tester,
  ) async {
    failUntilFixed(
      TlsFailure(root, certificateRejected: true),
      oauthServer230(),
    );
    await pump(tester);
    await submit(tester, 'vikunja.example.com');

    await tester.tap(find.text(en.connectionViewCertificate));
    await tester.pumpAndSettle();
    expect(find.byType(CertificatePage), findsOneWidget);
    await tester.ensureVisible(find.text(en.connectionTrustCertificate));
    await tester.tap(find.text(en.connectionTrustCertificate));
    await tester.pumpAndSettle();

    expect(connector.inputs, ['vikunja.example.com', 'vikunja.example.com']);
    expect(find.byType(ServerOverviewScreen), findsOneWidget);
  });

  testWidgets('leaving the certificate untrusted does not connect again', (
    tester,
  ) async {
    connector = FakeServerConnector.failing(
      TlsFailure(root, certificateRejected: true),
    );
    await pump(tester);
    await submit(tester, 'vikunja.example.com');

    await tester.tap(find.text(en.connectionViewCertificate));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(connector.inputs, hasLength(1));
    expect(find.text(en.connectionViewCertificate), findsOneWidget);
  });

  testWidgets('a shared link behind an untrusted certificate opens as a '
      'guest once it is trusted, without sending the link again', (
    tester,
  ) async {
    final server = fullServer270();
    final shareRoot = Uri.parse('https://tasks.example.org/vikunja/');
    failUntilFixed(TlsFailure(shareRoot, certificateRejected: true), server);
    auth.linkShareGateway.serve(
      issueLinkShareToken(issuedAt: DateTime.now().toUtc()),
    );
    await pump(tester);
    await submit(tester, shareLink());

    expect(find.text(en.connectionViewCertificate), findsOneWidget);
    expect(auth.linkShareGateway.authentications, isEmpty);
    await tester.tap(find.text(en.connectionViewCertificate));
    await tester.pumpAndSettle();
    expect(checks.fetches, [OriginKey.of(shareRoot)]);
    await tester.ensureVisible(find.text(en.connectionTrustCertificate));
    await tester.tap(find.text(en.connectionTrustCertificate));
    await tester.pumpAndSettle();

    expect(connector.inputs, hasLength(2));
    expect(auth.linkShareGateway.authentications, [(fakeShareHash, null)]);
    expect(find.byType(ProjectTasksScreen), findsOneWidget);
    final registry = await auth.registry.load();
    expect(registry.activeAccountId, linkShareAccountIdFor(server.rootUri, 84));
  });

  testWidgets('a shared link on http records the consent before the guest '
      'signs in, and opens on the first acceptance', (tester) async {
    final server = insecureServer();
    final plain = OriginKey.of(server.rootUri);
    connector.handler = (_) async => server;
    bool? consentAtSignIn;
    final token = issueLinkShareToken(issuedAt: DateTime.now().toUtc());
    auth.linkShareGateway.onAuthenticate = (hash, password) async {
      consentAtSignIn = (await profilesOver(auth).metadataFor(plain))
          ?.hasCleartextConsent;
      return linkShareAuthFor(token);
    };
    await pump(tester);
    await submit(tester, shareLink(base: 'http://192.168.1.20:3456/'));

    expect(find.text(en.insecureDialogTitle), findsOneWidget);
    await tester.tap(find.text(en.insecureDialogContinue));
    await tester.pumpAndSettle();

    expect(consentAtSignIn, isTrue);
    expect(auth.linkShareGateway.authentications, hasLength(1));
    expect(find.byType(ProjectTasksScreen), findsOneWidget);
  });

  testWidgets('a guest refused for its client certificate is offered one', (
    tester,
  ) async {
    connector.handler = (_) async => fullServer270();
    auth.linkShareGateway.onAuthenticate = (_, _) async =>
        throw const NetworkFailure(NetworkProblem.clientCertificate);
    await pump(tester);
    await submit(tester, shareLink());

    expect(
      find.text(en.connectionClientCertificateFailureTitle),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextButton, en.connectionAddClientCertificate),
      findsOneWidget,
    );
  });

  testWidgets('a login proxy leads to the headers editor of that origin', (
    tester,
  ) async {
    connector = FakeServerConnector.failing(BehindLoginProxy(root));
    await pump(tester);
    await submit(tester, 'vikunja.example.com');

    await tester.tap(find.text(en.connectionAddHeaders));
    await tester.pumpAndSettle();

    expect(find.byType(HeadersPage), findsOneWidget);
    expect(find.text('$origin'), findsOneWidget);
  });

  testWidgets('unreadable settings are reset after the confirmation, then '
      'the address connects', (tester) async {
    auth.preferences.values[NetworkProfiles.storageKey] = '{not json';
    failUntilFixed(
      ConnectionSettingsFailure(
        root,
        problem: ConnectionSettingsProblem.damaged,
      ),
      oauthServer230(),
    );
    await pump(tester);
    await submit(tester, 'vikunja.example.com');

    await tester.tap(find.text(en.connectionReset));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.connectionResetConfirm));
    await tester.pumpAndSettle();

    expect(
      await profilesOver(auth).metadataFor(origin),
      isNull,
      reason: 'readable again',
    );
    expect(connector.inputs, hasLength(2));
    expect(find.byType(ServerOverviewScreen), findsOneWidget);
  });

  group('Connection options', () {
    String optionsText(WidgetTester tester) => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(ConnectionOptionsButton),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data)
        .join('|');

    testWidgets('are disabled until the text names an address, then name '
        'its origin exactly', (tester) async {
      await pump(tester);

      TextButton button() => tester.widget<TextButton>(
        find.descendant(
          of: find.byType(ConnectionOptionsButton),
          matching: find.byWidgetPredicate((widget) => widget is TextButton),
        ),
      );
      expect(button().onPressed, isNull);

      await tester.enterText(_addressField, 'vikunja.example.com');
      await tester.pumpAndSettle();
      expect(button().onPressed, isNotNull);
      expect(optionsText(tester), contains(en.connectionOptionsFor('$origin')));

      await tester.enterText(_addressField, 'vikunja.example.com:3456');
      await tester.pumpAndSettle();
      expect(
        optionsText(tester),
        contains(en.connectionOptionsFor('https://vikunja.example.com:3456')),
      );

      await tester.enterText(_addressField, shareLink());
      await tester.pumpAndSettle();
      expect(
        optionsText(tester),
        contains(en.connectionOptionsFor('https://tasks.example.org:443')),
      );

      await tester.enterText(_addressField, 'not an address');
      await tester.pumpAndSettle();
      expect(button().onPressed, isNull);
    });

    testWidgets('mark an address with saved settings and open its screen', (
      tester,
    ) async {
      await pump(tester);
      await profilesOver(auth)
          .trustCertificate(origin, tlsFixtureCertificate('selfsigned.pem'));

      await tester.enterText(_addressField, 'vikunja.example.com');
      await tester.pumpAndSettle();
      expect(optionsText(tester), contains(en.connectionOptionsSaved));

      await tester.tap(find.text(en.connectionOptions));
      await tester.pumpAndSettle();
      expect(find.byType(ConnectionPage), findsOneWidget);
      expect(find.text(en.connectionPinnedTitle), findsOneWidget);
    });
  });
}
