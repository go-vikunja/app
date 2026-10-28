import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/common/presentation/app_bar_text_action.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_edit_page.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

/// iOS's largest accessibility text size.
const double _largestIosTextScale = 53 / 17;

void main() {
  testWidgets('the label grows with the text up to twice its size', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = _largestIosTextScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              AppBarTextAction(
                onPressed: () => pressed++,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );

    final scaler = MediaQuery.textScalerOf(tester.element(find.text('Save')));
    expect(scaler.scale(10), 20);
    expect(find.widgetWithText(TextButton, 'Save'), findsOneWidget);
    await tester.tap(find.text('Save'));
    expect(pressed, 1);
  });

  group('the German edit page at the largest iOS text size', () {
    final now = DateTime(2026, 10, 10, 12);

    for (final size in const [Size(375, 667), Size(320, 568)]) {
      testWidgets('fits its app bar on ${size.width.toInt()} points', (
        tester,
      ) async {
        usePhoneSurface(tester, logicalSize: size);
        useLocale(tester, const Locale('de'));
        tester.platformDispatcher.textScaleFactorTestValue =
            _largestIosTextScale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final data = SyncFakes(now: now)
          ..projects.all = [sampleProject(id: 1, title: 'Work')]
          ..tasks.all = [
            sampleTask(
              id: 1,
              title: 'Quarterly report',
              due: DateTime(2026, 10, 12, 9, 30),
            ),
          ];
        await pumpSignedInApp(tester, sync: data, now: now);
        unawaited(
          containerOf(tester)
              .read(appRouterProvider)
              .push(AppRoutes.taskEdit(1)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TaskEditPage), findsOneWidget);
        expect(
          find.widgetWithText(TextButton, de.taskEditSave),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    }
  });
}
