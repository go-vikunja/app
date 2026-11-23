import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/vikunja_app.dart';
import 'package:vikunja_mobile/bootstrap/bootstrap.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/features/connection/presentation/certificate_page.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_page.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';

import '../helpers/connection_fakes.dart';
import '../helpers/pump_app.dart';

// Android hands the data of any intent another app sends to the exported
// MainActivity to the router as a pushed route, whatever its scheme, a bare
// path included (G1). None of them may navigate.
void main() {
  const pushed = [
    'x://y/home/account-settings/api-tokens/new',
    '/home/account-settings/api-tokens/new',
    'x://y/connection?origin=https://attacker.example&edit=certificate',
    '/connection?origin=https://attacker.example&edit=certificate',
  ];

  late FakeCertificateChecks checks;

  setUp(() => checks = FakeCertificateChecks());

  GoRouter routerOf(WidgetTester tester) =>
      containerOf(tester).read(appRouterProvider);

  String location(WidgetTester tester) => routerOf(tester).state.uri.toString();

  Future<bool> pushInformation(WidgetTester tester, String route) async {
    Object? handled;
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.navigation.name,
      SystemChannels.navigation.codec.encodeMethodCall(
        MethodCall('pushRouteInformation', {'location': route, 'state': null}),
      ),
      (reply) =>
          handled = SystemChannels.navigation.codec.decodeEnvelope(reply!),
    );
    return handled == true;
  }

  Future<void> expectNoNavigation(WidgetTester tester) async {
    final before = location(tester);
    for (final route in pushed) {
      expect(
        await tester.binding.handlePushRoute(route),
        isTrue,
        reason: route,
      );
      await tester.pumpAndSettle();
      expect(location(tester), before, reason: route);

      expect(await pushInformation(tester, route), isTrue, reason: route);
      await tester.pumpAndSettle();
      expect(location(tester), before, reason: route);
    }
    expect(find.byType(ConnectionPage), findsNothing);
    expect(find.byType(CertificatePage), findsNothing);
    expect(checks.fetches, isEmpty);
    expect(tester.takeException(), isNull);
  }

  testWidgets('signed out, no pushed route navigates', (tester) async {
    await pumpVikunjaApp(tester, overrides: [checks.providerOverride]);
    expect(find.byType(ConnectServerScreen), findsOneWidget);

    await expectNoNavigation(tester);

    expect(location(tester), AppRoutes.connect);
  });

  testWidgets('signed in, no pushed route navigates', (tester) async {
    await pumpSignedInApp(tester, overrides: [checks.providerOverride]);
    expect(location(tester), AppRoutes.overview);

    await expectNoNavigation(tester);
  });

  testWidgets('a full URI that app code would go to is no route either', (
    tester,
  ) async {
    await pumpSignedInApp(tester, overrides: [checks.providerOverride]);

    routerOf(tester).go(pushed.first);
    await tester.pumpAndSettle();

    expect(routerOf(tester).state.matchedLocation, AppRoutes.overview);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a link with an escape that is no UTF-8 reports nothing and '
      'no route pushed before the app runs navigates: the app takes each '
      'before any other observer reads it', (tester) async {
    const broken = '$oauthCallbackScheme://widget/task/1?account=%FF';
    // In bootstrap's order: no View yet (the test binding puts one up before
    // each test, and the View observes the binding too), the early routes,
    // the container, the providers bootstrap reads before runApp, many of
    // which add an AppLifecycleListener, then runApp.
    await tester.pumpWidget(
      const ViewCollection(views: []),
      wrapWithView: false,
    );
    final earlyRoutes = EarlyPushedRoutes();
    addTearDown(() => tester.binding.removeObserver(earlyRoutes));
    for (final route in [broken, ...pushed]) {
      expect(await pushInformation(tester, route), isTrue, reason: route);
    }
    final container = createAppContainer(
      overrides: [...appOverrides(), checks.providerOverride],
      earlyRoutes: earlyRoutes,
    );
    addTearDown(container.dispose);
    final lifecycle = AppLifecycleListener();
    addTearDown(lifecycle.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const VikunjaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(location(tester), AppRoutes.connect);

    expect(await pushInformation(tester, broken), isTrue);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(location(tester), AppRoutes.connect);
    expect(find.byType(ConnectionPage), findsNothing);
    expect(checks.fetches, isEmpty);

    // Explicitly too, so that the app's timers do not outlive the test.
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
