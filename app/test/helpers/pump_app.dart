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
import 'package:vikunja_mobile/features/onboarding/application/current_server.dart';

import 'auth_fakes.dart';
import 'fakes.dart';

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
}) => [
  serverConnectorProvider.overrideWithValue(connector ?? FakeServerConnector()),
  externalLinkOpenerProvider.overrideWithValue(
    linkOpener ?? FakeExternalLinkOpener(),
  ),
  ...(auth ?? AuthFakes()).overrides,
];

Future<void> pumpVikunjaApp(
  WidgetTester tester, {
  FakeServerConnector? connector,
  FakeExternalLinkOpener? linkOpener,
  AuthFakes? auth,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...appOverrides(
          connector: connector,
          linkOpener: linkOpener,
          auth: auth,
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
