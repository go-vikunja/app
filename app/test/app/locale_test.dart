import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';

import '../helpers/pump_app.dart';

void main() {
  Locale appLocale(WidgetTester tester) =>
      Localizations.localeOf(tester.element(find.byType(ConnectServerScreen)));

  testWidgets('an unsupported device language falls back to English', (
    tester,
  ) async {
    useLocale(tester, const Locale('fr', 'FR'));
    await pumpVikunjaApp(tester);

    expect(appLocale(tester), const Locale('en'));
    expect(find.text(en.connectTagline), findsOneWidget);
  });

  testWidgets('a German device gets German', (tester) async {
    useLocale(tester, const Locale('de', 'AT'));
    await pumpVikunjaApp(tester);

    expect(appLocale(tester), const Locale('de'));
    expect(find.text(de.connectTagline), findsOneWidget);
  });
}
