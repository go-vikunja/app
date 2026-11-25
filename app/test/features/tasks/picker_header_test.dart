import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';

void main() {
  Future<void> pumpHeader(WidgetTester tester, VoidCallback? onAction) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: Scaffold(
            body: PickerHeader(
              title: 'New team',
              actionLabel: 'Create',
              onAction: onAction,
            ),
          ),
        ),
      );

  testWidgets("iOS: the header's action says it is disabled while it cannot "
      'run, and runs once from a screen reader once it can', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpHeader(tester, null);

    expect(
      tester.getSemantics(find.text('Create')),
      isSemantics(
        label: 'Create',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        hasTapAction: false,
      ),
    );

    var runs = 0;
    await pumpHeader(tester, () => runs++);

    expect(
      tester.getSemantics(find.text('Create')),
      isSemantics(
        label: 'Create',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    tester.semantics.tap(find.semantics.byLabel('Create'));
    await tester.pump();
    expect(runs, 1);
    handle.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
