import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' as intl;
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/l10n/shipped_locales.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';

import '../helpers/pump_app.dart';

void main() {
  BuildContext screen(WidgetTester tester) =>
      tester.element(find.byType(ConnectServerScreen));

  Locale appLocale(WidgetTester tester) =>
      Localizations.localeOf(screen(tester));

  MaterialLocalizations material(WidgetTester tester) =>
      MaterialLocalizations.of(screen(tester));

  final day = DateTime(2026, 10, 13);

  testWidgets('the app offers the shipped languages, not every ARB file', (
    tester,
  ) async {
    await pumpVikunjaApp(tester);

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).supportedLocales,
      shippedLocales,
    );
  });

  testWidgets('a device language the app does not ship falls back to '
      'English', (tester) async {
    useLocale(tester, const Locale('fr', 'FR'));
    await pumpVikunjaApp(tester);

    expect(appLocale(tester), const Locale('en'));
    expect(find.text(en.connectTagline), findsOneWidget);
  });

  testWidgets('a German device gets German in its region', (tester) async {
    useLocale(tester, const Locale('de', 'AT'));
    await pumpVikunjaApp(tester);

    expect(appLocale(tester), const Locale('de', 'AT'));
    expect(find.text(de.connectTagline), findsOneWidget);
  });

  testWidgets('a British device gets English texts with British dates and '
      'Monday first', (tester) async {
    useLocale(tester, const Locale('en', 'GB'));
    await pumpVikunjaApp(tester);

    expect(appLocale(tester), const Locale('en', 'GB'));
    expect(find.text(en.connectTagline), findsOneWidget);
    final l10n = screen(tester).l10n;
    expect(l10n.localeName, 'en_GB');
    expect(intl.DateFormat.yMMMd(l10n.localeName).format(day), '13 Oct 2026');
    expect(material(tester).formatCompactDate(day), '13/10/2026');
    expect(material(tester).firstDayOfWeekIndex, 1);
    expect(material(tester).dateHelpText, 'dd/mm/yyyy');
    expect(
      material(tester).dialogLabel,
      'Dialog',
      reason: "Material's texts stay the app's US English",
    );
  });

  testWidgets("a British device's clock follows the device's 24-hour switch, "
      'unless the account sets one', (tester) async {
    useLocale(tester, const Locale('en', 'GB'));
    await pumpVikunjaApp(tester);
    String clock({required bool device24Hour, TimeFormat? account}) =>
        MomentFormatter(
          l10n: screen(tester).l10n,
          material: material(tester),
          settings: DisplaySettings(timeFormat: account),
          alwaysUse24HourFormat: device24Hour,
        ).timeOfDay(DateTime(2026, 10, 13, 14, 5));

    expect(clock(device24Hour: false), '2:05 PM');
    expect(clock(device24Hour: true), '14:05');
    expect(
      clock(device24Hour: false, account: TimeFormat.twentyFourHour),
      '14:05',
    );
    expect(
      clock(device24Hour: true, account: TimeFormat.twelveHour),
      '2:05 PM',
    );
  });

  testWidgets("a German device's clock follows the device's 24-hour switch, "
      'unless the account sets one', (tester) async {
    useLocale(tester, const Locale('de', 'DE'));
    await pumpVikunjaApp(tester);
    String clock({required bool device24Hour, TimeFormat? account}) =>
        MomentFormatter(
          l10n: screen(tester).l10n,
          material: material(tester),
          settings: DisplaySettings(timeFormat: account),
          alwaysUse24HourFormat: device24Hour,
        ).timeOfDay(DateTime(2026, 10, 13, 14, 5));

    expect(clock(device24Hour: false), '2:05 PM');
    expect(clock(device24Hour: true), '14:05');
    expect(
      clock(device24Hour: false, account: TimeFormat.twentyFourHour),
      '14:05',
    );
    expect(
      clock(device24Hour: true, account: TimeFormat.twelveHour),
      '2:05 PM',
    );
  });

  testWidgets('a US device keeps US dates and Sunday first', (tester) async {
    useLocale(tester, const Locale('en', 'US'));
    await pumpVikunjaApp(tester);

    expect(appLocale(tester), const Locale('en', 'US'));
    expect(find.text(en.connectTagline), findsOneWidget);
    expect(
      intl.DateFormat.yMMMd(screen(tester).l10n.localeName).format(day),
      'Oct 13, 2026',
    );
    expect(material(tester).formatCompactDate(day), '10/13/2026');
    expect(material(tester).firstDayOfWeekIndex, 0);
    expect(material(tester).dateHelpText, 'mm/dd/yyyy');
    expect(
      material(tester).timeOfDayFormat(),
      TimeOfDayFormat.h_colon_mm_space_a,
    );
  });

  testWidgets("a Swiss device keeps German texts, Material's too, with Swiss "
      'numbers', (tester) async {
    useLocale(tester, const Locale('de', 'CH'));
    await pumpVikunjaApp(tester);

    expect(appLocale(tester), const Locale('de', 'CH'));
    expect(find.text(de.connectTagline), findsOneWidget);
    expect(material(tester).cancelButtonLabel, 'Abbrechen');
    expect(material(tester).formatCompactDate(day), '13.10.2026');
    expect(material(tester).formatDecimal(1234567), "1'234'567");
    expect(material(tester).firstDayOfWeekIndex, 1);
  });

  testWidgets("a per-app language keeps the device's region of that "
      'language, and only of that one', (tester) async {
    tester.platformDispatcher.localesTestValue = const [
      Locale('en'),
      Locale('en', 'GB'),
    ];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await pumpVikunjaApp(tester);

    expect(appLocale(tester), const Locale('en', 'GB'));

    tester.platformDispatcher.localesTestValue = const [
      Locale('de'),
      Locale('en', 'GB'),
    ];
    await tester.pumpAndSettle();

    expect(appLocale(tester), const Locale('de'));
    expect(find.text(de.connectTagline), findsOneWidget);
    expect(material(tester).formatCompactDate(day), '13.10.2026');
  });
}
