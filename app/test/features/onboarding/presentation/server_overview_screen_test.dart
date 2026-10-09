import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_overview_screen.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/server_connections.dart';

final Finder _continueButton = find.widgetWithText(
  FilledButton,
  en.continueToSignIn,
);

void _expectTexts(Iterable<String> texts, Matcher matcher) {
  for (final text in texts) {
    expect(find.text(text), matcher, reason: text);
  }
}

void main() {
  // Tall enough that the whole lazily built list is laid out at once.
  void useTallSurface(WidgetTester tester) =>
      usePhoneSurface(tester, logicalSize: const Size(400, 2400));

  testWidgets('2.3 server: oauth tier with browser sign-in only', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpServerOverview(tester, oauthServer230());

    expect(find.bySemanticsLabel('vikunja.example.com'), findsOneWidget);
    _expectTexts([
      en.overviewTitle,
      en.overviewVikunjaVersion('2.3.0'),
      en.overviewApiBadge('v1'),
      en.tierOauthTitle,
      en.tierOauthBody,
      en.signInMethodsHeading,
      en.signInBrowserTitle,
      en.signInBrowserSubtitle,
      en.featureAttachmentsWithLimit('20\u00A0MB'),
      en.featureComments,
      en.featureLinkSharing,
      en.featureTotp,
      en.featureCaldav,
      en.featureWebhooks,
      en.featureEmailReminders,
      en.featureRegistration,
      en.featureUserDeletion,
      en.featureBackgrounds,
    ], findsOneWidget);
    _expectTexts([
      en.overviewApiBadge('v2'),
      en.tierOauthV2UnreachableBody,
      en.featurePublicTeams,
      en.motdHeading,
      en.unsupportedTitle,
      en.overviewInsecureBadge,
      en.legalImprint,
    ], findsNothing);
    expect(find.byType(ListTile), findsOneWidget);
    expect(_continueButton, findsOneWidget);
  });

  testWidgets('continuing announces that sign-in comes next', (tester) async {
    useTallSurface(tester);
    await pumpServerOverview(tester, oauthServer230());

    await tester.tap(_continueButton);
    await tester.pump();

    expect(find.text(en.signInComingSoon), findsOneWidget);
  });

  testWidgets('2.0 server: too old for browser sign-in, even with OIDC', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpServerOverview(
      tester,
      legacyServer200(
        openIdProviders: const [
          OpenIdProvider(name: 'Keycloak', key: 'keycloak'),
        ],
      ),
    );

    _expectTexts([
      en.overviewVikunjaVersion('2.0.0'),
      en.unsupportedTitle,
      en.unsupportedBody('2.3.0', '2.0.0'),
      en.unsupportedSuggestion,
    ], findsOneWidget);
    _expectTexts([
      en.tierOauthTitle,
      en.tierFullTitle,
      en.signInMethodsHeading,
      en.signInBrowserTitle,
      en.featuresHeading,
      en.continueToSignIn,
    ], findsNothing);
    expect(find.textContaining('Keycloak'), findsNothing);
    expect(
      find.widgetWithText(FilledButton, en.useDifferentServer),
      findsOneWidget,
    );
  });

  testWidgets('2.7 server: full tier with OIDC, LDAP, licensed features', (
    tester,
  ) async {
    final linkOpener = FakeExternalLinkOpener();
    useTallSurface(tester);
    await pumpServerOverview(tester, fullServer270(), linkOpener: linkOpener);

    expect(find.bySemanticsLabel('tasks.example.org'), findsOneWidget);
    _expectTexts([
      '/vikunja',
      en.overviewVikunjaVersion('2.7.0'),
      en.overviewApiBadge('v2'),
      en.overviewApiBadge('v1'),
      en.tierFullTitle,
      en.tierFullBody,
      en.signInMethodsHeading,
      en.signInBrowserTitle,
      en.signInBrowserProvidersSubtitle('Keycloak, Authentik'),
      en.featurePublicTeams,
      en.motdHeading,
      en.legalImprint,
    ], findsOneWidget);
    // Dropped and deferred features (D20) are not advertised, even when the
    // server is licensed for them.
    expect(find.byIcon(Icons.admin_panel_settings_outlined), findsNothing);
    expect(find.byIcon(Icons.timer_outlined), findsNothing);
    expect(
      find.widgetWithText(
        SelectableText,
        'Maintenance on Sunday from 02:00 to 03:00.',
      ),
      findsOneWidget,
    );
    expect(find.text(en.legalPrivacy), findsNothing);
    expect(find.text(en.signInBrowserSubtitle), findsNothing);
    expect(find.byType(ListTile), findsOneWidget);

    final badges = tester
        .widgetList<Text>(find.textContaining('API v'))
        .map((text) => text.data)
        .toList();
    expect(badges, ['API v2', 'API v1']);

    await tester.tap(find.text(en.legalImprint));
    await tester.pump();
    expect(linkOpener.opened, [Uri.parse('https://example.org/imprint')]);
  });

  testWidgets('a link that cannot be opened shows a message', (tester) async {
    useTallSurface(tester);
    await pumpServerOverview(
      tester,
      fullServer270(),
      linkOpener: FakeExternalLinkOpener(succeeds: false),
    );

    await tester.tap(find.text(en.legalImprint));
    await tester.pump();

    expect(find.text(en.legalOpenFailed), findsOneWidget);
  });

  testWidgets('2.7 server without a reachable /api/v2 blames the proxy', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpServerOverview(tester, v1OnlyServer270());

    _expectTexts([
      en.overviewVikunjaVersion('2.7.0'),
      en.tierOauthTitle,
      en.tierOauthV2UnreachableBody,
      en.signInBrowserTitle,
    ], findsOneWidget);
    _expectTexts([en.tierOauthBody, en.overviewApiBadge('v2')], findsNothing);
  });

  testWidgets('1.0 server: blocking banner and no way to continue', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpServerOverview(tester, legacyServer100());

    _expectTexts([
      en.overviewVikunjaVersion('1.0.0'),
      en.overviewApiBadge('v1'),
      en.unsupportedTitle,
      en.unsupportedBody('2.3.0', '1.0.0'),
      en.unsupportedSuggestion,
    ], findsOneWidget);
    _expectTexts([
      en.tierFullTitle,
      en.tierOauthTitle,
      en.signInMethodsHeading,
      en.featuresHeading,
      en.continueToSignIn,
    ], findsNothing);
    expect(
      find.widgetWithText(FilledButton, en.useDifferentServer),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextButton, en.useDifferentServer),
      findsNothing,
    );

    await tester.tap(find.text(en.useDifferentServer));
    await tester.pumpAndSettle();
    expect(find.byType(ConnectServerScreen), findsOneWidget);
  });

  testWidgets('a version that cannot be parsed is not called too old', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpServerOverview(tester, unknownVersionServer());

    _expectTexts([
      en.overviewVikunjaVersion('custom-2024'),
      en.unsupportedUnknownVersionTitle,
      en.unsupportedUnknownVersionBody('2.3.0'),
      en.unsupportedUnknownVersionSuggestion,
    ], findsOneWidget);
    _expectTexts([
      en.unsupportedTitle,
      en.unsupportedSuggestion,
      en.signInMethodsHeading,
    ], findsNothing);
  });

  testWidgets('an empty version string reads as unknown', (tester) async {
    useTallSurface(tester);
    await pumpServerOverview(tester, unknownVersionServer(version: ''));

    expect(find.text(en.overviewVikunjaVersionUnknown), findsOneWidget);
  });

  group('attachment limit', () {
    final info = jsonDecode(
      File('../packages/vikunja_api/test/fixtures/info_v2_2.7.0.json')
          .readAsStringSync(),
    ) as Map<String, Object?>;

    ServerConnection withMaxFileSize(Object? maxFileSize) {
      final parsed = parseServerInfo({...info, 'max_file_size': maxFileSize});
      const apiVersions = {ApiVersion.v1, ApiVersion.v2};
      return ServerConnection(
        rootUri: Uri.parse('https://vikunja.example.com'),
        apiVersions: apiVersions,
        info: parsed,
        capabilities: ServerCapabilities.derive(
          info: parsed,
          apiVersions: apiVersions,
        ),
      );
    }

    for (final (configured, expected) in [
      ('500KB', en.featureAttachmentsWithLimit('20\u00A0MB')),
      ('104857600', en.featureAttachmentsWithLimit('100\u00A0MB')),
      ('1536mb', en.featureAttachmentsWithLimit('1.5\u00A0GB')),
      ('1.5GB', en.featureAttachmentsWithLimit('1.5GB')),
      (null, en.featureAttachments),
    ]) {
      testWidgets('max_file_size $configured shows "$expected"', (
        tester,
      ) async {
        useTallSurface(tester);
        await pumpServerOverview(tester, withMaxFileSize(configured));

        expect(find.text(expected), findsOneWidget);
      });
    }

    testWidgets('is formatted for the German locale', (tester) async {
      useTallSurface(tester);
      useLocale(tester, const Locale('de'));
      await pumpServerOverview(tester, withMaxFileSize('1536MB'));

      expect(
        find.text(de.featureAttachmentsWithLimit('1,5\u00A0GB')),
        findsOneWidget,
      );
    });
  });

  testWidgets('"Use a different server" returns to the connect screen', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpServerOverview(tester, oauthServer230());

    await tester.tap(find.text(en.useDifferentServer));
    await tester.pumpAndSettle();

    expect(find.byType(ServerOverviewScreen), findsNothing);
    expect(find.byType(ConnectServerScreen), findsOneWidget);
  });

  testWidgets('the back button returns to the connect screen', (tester) async {
    useTallSurface(tester);
    await pumpServerOverview(tester, oauthServer230());

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(ConnectServerScreen), findsOneWidget);
  });
}
