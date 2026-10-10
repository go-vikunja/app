import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/vikunja_app.dart';
import 'package:vikunja_mobile/core/links/external_link_opener.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/onboarding/application/current_server.dart';

import 'auth_fakes.dart';
import 'fake_read_client.dart';
import 'fakes.dart';
import 'server_connections.dart';

final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
final AppLocalizations de = lookupAppLocalizations(const Locale('de'));

const phoneSize = Size(360, 740);

void usePhoneSurface(WidgetTester tester, {Size logicalSize = phoneSize}) {
  tester.view
    ..devicePixelRatio = 3
    ..physicalSize = logicalSize * 3;
  addTearDown(tester.view.reset);
}

void useLocale(WidgetTester tester, Locale locale) {
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

void useAccessibilityExtremes(WidgetTester tester) {
  tester.platformDispatcher
    ..textScaleFactorTestValue = 2
    ..platformBrightnessTestValue = Brightness.dark;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(VikunjaApp)));

List<Override> appOverrides({
  FakeServerConnector? connector,
  FakeExternalLinkOpener? linkOpener,
  AuthFakes? auth,
  FakeReadClient? readClient,
}) {
  final client = readClient ?? FakeReadClient();
  return [
    serverConnectorProvider.overrideWithValue(
      connector ?? FakeServerConnector(),
    ),
    externalLinkOpenerProvider.overrideWithValue(
      linkOpener ?? FakeExternalLinkOpener(),
    ),
    // Every account reads from the same fake.
    readClientProvider.overrideWith((ref, accountId) => client),
    ...(auth ?? AuthFakes()).overrides,
  ];
}

Future<void> pumpVikunjaApp(
  WidgetTester tester, {
  FakeServerConnector? connector,
  FakeExternalLinkOpener? linkOpener,
  AuthFakes? auth,
  FakeReadClient? readClient,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...appOverrides(
          connector: connector,
          linkOpener: linkOpener,
          auth: auth,
          readClient: readClient,
        ),
        ...overrides,
      ],
      child: const VikunjaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pumpServerOverview(
  WidgetTester tester,
  ServerConnection connection, {
  FakeExternalLinkOpener? linkOpener,
  AuthFakes? auth,
}) async {
  await pumpVikunjaApp(tester, linkOpener: linkOpener, auth: auth);
  final container = containerOf(tester);
  container.read(currentServerProvider.notifier).select(connection);
  container.read(appRouterProvider).go(AppRoutes.serverOverview);
  await tester.pumpAndSettle();
}

/// Switches to the tab whose bar label is [label], e.g. `en.tabAccount`.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Starts the app signed in to a 2.7 server, reading through [readClient].
Future<AuthFakes> pumpSignedInApp(
  WidgetTester tester, {
  FakeReadClient? readClient,
  AuthFakes? auth,
  DateTime? now,
  List<Override> overrides = const [],
}) async {
  final fakes = auth ?? AuthFakes();
  await fakes.seedAccount(
    fullServer270(),
    tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
  );
  await pumpVikunjaApp(
    tester,
    auth: fakes,
    readClient: readClient,
    overrides: [
      if (now != null) clockProvider.overrideWithValue(() => now),
      ...overrides,
    ],
  );
  return fakes;
}

/// Pulls down on [scrollable] far enough to trigger the refresh indicator.
Future<void> pullToRefresh(WidgetTester tester, Finder scrollable) async {
  // The indicator triggers at a quarter of the viewport height.
  final extent = tester.getSize(scrollable).height;
  await tester.fling(scrollable, Offset(0, extent * 0.5), 1000);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}
