import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

import '../../helpers/label_user_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sync_fakes.dart';

/// Opens the edit page of [taskId] over [data], with [labels] and [users]
/// as the label and people repositories. Tall enough for the whole form,
/// which the list builds lazily.
Future<void> openEditPageWith(
  WidgetTester tester, {
  required SyncFakes data,
  required int taskId,
  required DateTime now,
  FakeLabelRepository? labels,
  FakeUserRepository? users,
  Size size = const Size(360, 2200),
}) async {
  usePhoneSurface(tester, logicalSize: size);
  await pumpSignedInApp(
    tester,
    sync: data,
    now: now,
    overrides: [
      labelRepositoryProvider.overrideWithValue(
        labels ?? FakeLabelRepository(),
      ),
      userRepositoryProvider.overrideWithValue(users ?? FakeUserRepository()),
    ],
  );
  unawaited(
    containerOf(tester)
        .read(appRouterProvider)
        .push(AppRoutes.taskEdit(taskId)),
  );
  await tester.pumpAndSettle();
}

Finder editSaveButton() => find.widgetWithText(TextButton, en.taskEditSave);

bool editSaveEnabled(WidgetTester tester) =>
    tester.widget<TextButton>(editSaveButton()).onPressed != null;

Future<void> saveEdits(WidgetTester tester) async {
  await tester.tap(editSaveButton());
  await tester.pumpAndSettle();
}

Future<void> tapPickerDone(WidgetTester tester) async {
  await tester.tap(find.text(en.pickerDone));
  await tester.pumpAndSettle();
}

/// Taps [finder] after scrolling it into view.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
