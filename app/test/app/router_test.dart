import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/onboarding/application/current_server.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_overview_screen.dart';

import '../helpers/pump_app.dart';
import '../helpers/server_connections.dart';

void main() {
  GoRouter routerOf(WidgetTester tester) =>
      containerOf(tester).read(appRouterProvider);

  String location(WidgetTester tester) =>
      routerOf(tester).routerDelegate.currentConfiguration.uri.toString();

  testWidgets('starts on the connect screen', (tester) async {
    await pumpVikunjaApp(tester);

    expect(location(tester), AppRoutes.connect);
    expect(find.byType(ConnectServerScreen), findsOneWidget);
  });

  testWidgets('redirects the overview to connect when no server is held', (
    tester,
  ) async {
    await pumpVikunjaApp(tester);

    routerOf(tester).go(AppRoutes.serverOverview);
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.connect);
    expect(find.byType(ServerOverviewScreen), findsNothing);
  });

  testWidgets('opens the overview when a server is held', (tester) async {
    await pumpVikunjaApp(tester);
    containerOf(tester)
        .read(currentServerProvider.notifier)
        .select(oauthServer230());

    routerOf(tester).go(AppRoutes.serverOverview);
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.serverOverview);
    expect(find.byType(ServerOverviewScreen), findsOneWidget);
  });

  testWidgets('leaves the overview when the server is cleared', (tester) async {
    await pumpServerOverview(tester, oauthServer230());

    containerOf(tester).read(currentServerProvider.notifier).clear();
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.connect);
    expect(find.byType(ServerOverviewScreen), findsNothing);
  });
}
