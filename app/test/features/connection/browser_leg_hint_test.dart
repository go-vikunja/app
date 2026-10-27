import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/features/connection/presentation/browser_leg_hint.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/connection_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/tls_fixtures.dart';

void main() {
  final selfSigned = tlsFixtureCertificate('selfsigned.pem');
  late AuthFakes auth;

  setUp(() => auth = AuthFakes());

  group('the hint', () {
    test(
      'is not needed without settings, nor for http consent alone',
      () async {
        final profiles = profilesOver(auth);
        final plain = insecureServer();
        await profiles.consentToCleartext(OriginKey.of(plain.rootUri));

        expect(await browserLegHint(en, profiles, oauthServer230()), isNull);
        expect(await browserLegHint(en, profiles, plain), isNull);
      },
    );

    test('shows the pinned fingerprint of the sign-in page', () async {
      final profiles = profilesOver(auth);
      final server = oauthServer230();
      await profiles.trustCertificate(OriginKey.of(server.rootUri), selfSigned);

      final hint = await browserLegHint(en, profiles, server);

      expect(hint?.pinnedFingerprint, selfSigned.sha256Pairs);
      expect(hint?.notes, isEmpty);
      expect(hint?.asText(en), contains(selfSigned.sha256Pairs.join(' ')));
    });

    test('words a trusted CA as a possible warning', () async {
      final profiles = profilesOver(auth);
      final server = oauthServer230();
      await profiles.trustCaCertificate(
        OriginKey.of(server.rootUri),
        fileName: 'ca.pem',
        pem: tlsFixtureText('ca.pem'),
      );

      final hint = await browserLegHint(en, profiles, server);

      expect(hint?.pinnedFingerprint, isNull);
      expect(hint?.notes, [en.connectionBrowserHintCa]);
    });

    test("names the API's client certificate and headers, and the sign-in "
        "page's own host", () async {
      final profiles = profilesOver(auth);
      final server = accountPagesServer270(
        root: 'https://api.example.org',
        frontendUrl: Uri.parse('https://tasks.example.org/'),
      );
      final api = OriginKey.of(server.rootUri);
      await profiles.setClientCertificate(
        api,
        fileName: 'client.p12',
        bytes: tlsFixture('client.p12'),
        password: tlsFixturePassword,
      );
      await profiles.setHeaders(api, {'X-Gate-Token': 'dummy'});

      final hint = await browserLegHint(en, profiles, server);

      expect(hint?.pinnedFingerprint, isNull);
      expect(hint?.notes, [
        en.connectionBrowserHintClientCertificate,
        en.connectionBrowserHintHeaders,
        en.connectionBrowserHintOtherHost('tasks.example.org'),
      ]);
    });

    test('a pinned API with its sign-in page elsewhere shows no fingerprint, '
        'only where sign-in opens', () async {
      final profiles = profilesOver(auth);
      final server = accountPagesServer270(
        root: 'https://api.example.org',
        frontendUrl: Uri.parse('https://tasks.example.org/'),
      );
      await profiles.trustCertificate(OriginKey.of(server.rootUri), selfSigned);

      final hint = await browserLegHint(en, profiles, server);

      expect(hint?.pinnedFingerprint, isNull);
      expect(hint?.notes, [
        en.connectionBrowserHintOtherHost('tasks.example.org'),
      ]);
    });
  });

  group('before the browser opens', () {
    final continueButton = find.widgetWithText(
      FilledButton,
      en.continueToSignIn,
    );

    testWidgets('without settings the browser opens at once', (tester) async {
      await pumpServerOverview(tester, oauthServer230(), auth: auth);

      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(find.text(en.connectionBrowserHintTitle), findsNothing);
      expect(auth.webAuthenticator.urls, hasLength(1));
    });

    testWidgets('a pinned server asks first with the fingerprint; Cancel '
        'opens nothing, Continue opens the browser', (tester) async {
      final server = oauthServer230();
      await pumpServerOverview(tester, server, auth: auth);
      await profilesOver(auth)
          .trustCertificate(OriginKey.of(server.rootUri), selfSigned);

      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.text(en.connectionBrowserHintTitle), findsOneWidget);
      expect(find.text(en.connectionBrowserHintPinned), findsOneWidget);
      await tester.tap(find.text(en.cancel));
      await tester.pumpAndSettle();
      expect(auth.webAuthenticator.urls, isEmpty);

      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.connectionBrowserHintContinue));
      await tester.pumpAndSettle();
      expect(auth.webAuthenticator.urls, hasLength(1));
    });

    testWidgets('creating an account says it in the question it asks '
        'anyway', (tester) async {
      final server = accountPagesServer270();
      await pumpServerOverview(tester, server, auth: auth);
      await profilesOver(auth)
          .setHeaders(OriginKey.of(server.rootUri), {'X-Gate-Token': 'dummy'});

      await tester.tap(find.text(en.overviewCreateAccount));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '${en.overviewCreateAccountHint}\n\n'
          '${en.connectionBrowserHintHeaders}',
        ),
        findsOneWidget,
      );
      expect(find.text(en.connectionBrowserHintTitle), findsNothing);
    });
  });
}
