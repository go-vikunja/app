import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/inbox/application/inbox_providers.dart';
import 'package:vikunja_mobile/features/inbox/presentation/inbox_button.dart';

void main() {
  testWidgets("the badge's count grows with the text only up to 1.3×", (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unreadActivityCountProvider.overrideWith((ref) => Stream.value(5)),
        ],
        child: const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(53 / 17)),
            child: Scaffold(body: Center(child: InboxButton())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final count = find.descendant(
      of: find.byType(Badge),
      matching: find.text('5'),
    );
    expect(count, findsOneWidget);
    expect(
      MediaQuery.textScalerOf(tester.element(count)).scale(10),
      closeTo(10 * InboxButton.maxBadgeTextScale, 0.001),
    );
    final icon = find.descendant(
      of: find.byType(Badge),
      matching: find.byType(Icon),
    );
    expect(
      MediaQuery.textScalerOf(tester.element(icon)).scale(10),
      closeTo(10 * 53 / 17, 0.001),
    );
  });
}
