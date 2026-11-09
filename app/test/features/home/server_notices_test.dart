import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/home/presentation/server_notices.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

const _motd = 'Maintenance on Sunday from 02:00 to 03:00.';

final _everyKindOfLink = LegalLinks(
  links: [
    LegalLink(
      text: LegalLink.imprintText,
      url: Uri.parse('https://example.org/imprint'),
    ),
    LegalLink(
      text: LegalLink.privacyPolicyText,
      url: Uri.parse('https://example.org/privacy'),
    ),
    LegalLink(
      text: 'Barrierefreiheit',
      url: Uri.parse('https://example.org/a11y'),
    ),
    LegalLink(text: 'imprint', url: Uri.parse('https://example.org/lower')),
  ],
);

/// The legal link buttons' texts in the Server section, in widget order.
List<String?> _legalLabels(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.descendant(
          of: find.byType(ServerNotices),
          matching: find.byType(TextButton),
        ),
        matching: find.byType(Text),
      ),
    )
    .map((text) => text.data)
    .toList();

void main() {
  late AuthFakes auth;
  late FakeExternalLinkOpener linkOpener;

  setUp(() {
    auth = AuthFakes();
    linkOpener = FakeExternalLinkOpener();
  });

  Future<void> pumpAccountTab(
    WidgetTester tester,
    ServerConnection connection, {
    String? tabLabel,
  }) async {
    final now = DateTime.now().toUtc();
    await auth.seedAccount(connection, tokens: issueTokens(issuedAt: now));
    await pumpVikunjaApp(
      tester,
      auth: auth,
      sync: SyncFakes(now: now),
      linkOpener: linkOpener,
    );
    await openTab(tester, tabLabel ?? en.tabAccount);
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      100,
      scrollable: find
          .descendant(
            of: find.byType(AccountTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pumpAndSettle();
  }

  testWidgets('the Server section shows the demo mode, the message and the '
      'legal links the server reported', (tester) async {
    await pumpAccountTab(tester, fullServer270(demoMode: true));

    await scrollTo(tester, find.byType(ServerNotices));
    expect(find.text(en.overviewDemoNote), findsOneWidget);
    expect(find.text(en.motdHeading), findsOneWidget);
    expect(find.widgetWithText(SelectableText, _motd), findsOneWidget);
    expect(find.text(en.legalImprint), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
    // Only web links are offered; the stored privacy link is javascript:.
    expect(find.text(en.legalPrivacy), findsNothing);

    final notices = tester.getRect(find.byType(ServerNotices));
    final version = tester.getRect(
      find.text(en.overviewVikunjaVersion('2.7.0')),
    );
    expect(notices.top, greaterThanOrEqualTo(version.bottom));

    await tester.tap(find.text(en.legalImprint));
    await tester.pump();
    expect(linkOpener.opened, [Uri.parse('https://example.org/imprint')]);
  });

  testWidgets('the demo note is read as one sentence without its icon', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpAccountTab(tester, fullServer270(demoMode: true));

    await scrollTo(tester, find.text(en.overviewDemoNote));
    expect(
      tester.getSemantics(find.text(en.overviewDemoNote)),
      matchesSemantics(label: en.overviewDemoNote),
    );
    semantics.dispose();
  });

  testWidgets('without a demo mode only the message and links show', (
    tester,
  ) async {
    await pumpAccountTab(tester, fullServer270());

    await scrollTo(tester, find.byType(ServerNotices));
    expect(find.text(en.overviewDemoNote), findsNothing);
    expect(find.widgetWithText(SelectableText, _motd), findsOneWidget);
    expect(find.text(en.legalImprint), findsOneWidget);
  });

  testWidgets('every legal link of a 2.8.0 server shows in its order, the '
      "imprint and the privacy policy in the app's words, the others as "
      'written', (tester) async {
    await pumpAccountTab(tester, fullServer280(legal: _everyKindOfLink));

    await scrollTo(tester, find.byType(ServerNotices));
    expect(_legalLabels(tester), [
      'Imprint',
      'Privacy policy',
      'Barrierefreiheit',
      'imprint',
    ]);
    await tester.tap(find.text('Barrierefreiheit'));
    await tester.pump();
    expect(linkOpener.opened, [Uri.parse('https://example.org/a11y')]);
  });

  testWidgets('every legal link of a 2.8.0 server in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await pumpAccountTab(
      tester,
      fullServer280(legal: _everyKindOfLink),
      tabLabel: de.tabAccount,
    );

    await scrollTo(tester, find.byType(ServerNotices));
    expect(_legalLabels(tester), [
      'Impressum',
      'Datenschutzerklärung',
      'Barrierefreiheit',
      'imprint',
    ]);
  });

  group('Imprint and Impressum at one address', () {
    final imprintTwice = LegalLinks(
      links: [
        LegalLink(
          text: LegalLink.imprintText,
          url: Uri.parse('https://example.org/imprint'),
        ),
        LegalLink(
          text: 'Impressum',
          url: Uri.parse('https://example.org/imprint'),
        ),
      ],
    );

    testWidgets('are two buttons in English', (tester) async {
      await pumpAccountTab(tester, fullServer280(legal: imprintTwice));

      await scrollTo(tester, find.byType(ServerNotices));
      expect(_legalLabels(tester), ['Imprint', 'Impressum']);
    });

    testWidgets('are one button in German, where both read Impressum', (
      tester,
    ) async {
      useLocale(tester, const Locale('de'));
      await pumpAccountTab(
        tester,
        fullServer280(legal: imprintTwice),
        tabLabel: de.tabAccount,
      );

      await scrollTo(tester, find.byType(ServerNotices));
      expect(_legalLabels(tester), ['Impressum']);
    });
  });

  testWidgets('a server without notices adds nothing', (tester) async {
    await pumpAccountTab(tester, oauthServer230());

    await scrollTo(tester, find.byType(ServerNotices));
    expect(tester.getSize(find.byType(ServerNotices)).height, 0);
    for (final text in [
      en.overviewDemoNote,
      en.motdHeading,
      en.legalImprint,
      en.legalPrivacy,
    ]) {
      expect(find.text(text), findsNothing, reason: text);
    }
  });

  testWidgets('a link that cannot be opened shows a message', (tester) async {
    linkOpener = FakeExternalLinkOpener(succeeds: false);
    await pumpAccountTab(tester, fullServer270());

    await scrollTo(tester, find.text(en.legalImprint));
    await tester.tap(find.text(en.legalImprint));
    await tester.pump();

    expect(find.text(en.legalOpenFailed), findsOneWidget);
  });

  testWidgets('is in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await pumpAccountTab(
      tester,
      fullServer270(demoMode: true),
      tabLabel: de.tabAccount,
    );

    await scrollTo(tester, find.byType(ServerNotices));
    expect(find.text(de.overviewDemoNote), findsOneWidget);
    expect(find.text(de.motdHeading), findsOneWidget);
    expect(find.text(de.legalImprint), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
  });
}
