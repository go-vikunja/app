import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

import '../a11y/sweep_data.dart';

/// Phones in both orientations and the 800×600 test surface lay out as
/// they did before step 36b (decision 6): every rect here was recorded at
/// 2d70ef1, from a `git archive` export. Self-contained, so it still runs
/// there.
const Map<TargetPlatform, List<Size>> _sizes = {
  TargetPlatform.android: [
    Size(360, 740),
    Size(740, 360),
    Size(952, 427),
    Size(800, 600),
  ],
  TargetPlatform.iOS: [Size(375, 667), Size(844, 390), Size(800, 600)],
};

const _expected = <String, Rect>{
  'android 360×740 overview card': Rect.fromLTRB(16, 372, 344, 526),
  'android 360×740 overview row': Rect.fromLTRB(16, 372, 344, 526),
  'android 360×740 task sheet': Rect.fromLTRB(0, 242.2, 360, 740),
  'android 360×740 long dialog': Rect.fromLTRB(40, 24, 320, 716),
  'android 360×740 account tile': Rect.fromLTRB(0, 236, 360, 420),
  'android 360×740 task edit field': Rect.fromLTRB(16, 64, 344, 120),
  'android 740×360 overview card': Rect.fromLTRB(144, 260, 724, 350),
  'android 740×360 overview row': Rect.fromLTRB(144, 260, 724, 350),
  'android 740×360 task sheet': Rect.fromLTRB(50, 109.19999999999999, 690, 360),
  'android 740×360 long dialog': Rect.fromLTRB(40, 24, 700, 336),
  'android 740×360 account tile': Rect.fromLTRB(128, 148, 740, 248),
  'android 740×360 task edit field': Rect.fromLTRB(16, 64, 724, 120),
  'android 952×427 overview card': Rect.fromLTRB(144, 260, 936, 330),
  'android 952×427 overview row': Rect.fromLTRB(144, 260, 936, 330),
  'android 952×427 task sheet': Rect.fromLTRB(
    156,
    132.64999999999998,
    796,
    427,
  ),
  'android 952×427 long dialog': Rect.fromLTRB(40, 24, 912, 403),
  'android 952×427 account tile': Rect.fromLTRB(128, 148, 952, 228),
  'android 952×427 task edit field': Rect.fromLTRB(16, 64, 936, 120),
  'android 800×600 overview card': Rect.fromLTRB(144, 260, 784, 350),
  'android 800×600 overview row': Rect.fromLTRB(144, 260, 784, 350),
  'android 800×600 task sheet': Rect.fromLTRB(80, 193.2, 720, 600),
  'android 800×600 long dialog': Rect.fromLTRB(40, 24, 760, 576),
  'android 800×600 account tile': Rect.fromLTRB(128, 148, 800, 248),
  'android 800×600 task edit field': Rect.fromLTRB(16, 64, 784, 120),
  'iOS 375×667 overview card': Rect.fromLTRB(16, 352, 359, 506),
  'iOS 375×667 overview row': Rect.fromLTRB(16, 352, 359, 506),
  'iOS 375×667 task sheet': Rect.fromLTRB(0, 53.36, 375, 667),
  'iOS 375×667 account tile': Rect.fromLTRB(0, 208, 375, 392),
  'iOS 375×667 task edit field': Rect.fromLTRB(16, 64, 359, 120),
  'iOS 844×390 overview card': Rect.fromLTRB(63, 260, 781, 330),
  'iOS 844×390 overview row': Rect.fromLTRB(63, 260, 781, 330),
  'iOS 844×390 task sheet': Rect.fromLTRB(0, 31.2, 844, 390),
  'iOS 844×390 account tile': Rect.fromLTRB(47, 148, 797, 228),
  'iOS 844×390 task edit field': Rect.fromLTRB(16, 64, 828, 120),
  'iOS 800×600 overview card': Rect.fromLTRB(16, 260, 784, 330),
  'iOS 800×600 overview row': Rect.fromLTRB(16, 260, 784, 330),
  'iOS 800×600 task sheet': Rect.fromLTRB(0, 48, 800, 600),
  'iOS 800×600 account tile': Rect.fromLTRB(0, 148, 800, 228),
  'iOS 800×600 task edit field': Rect.fromLTRB(16, 64, 784, 120),
};

String _name(Size size) =>
    '${size.width.toStringAsFixed(0)}×${size.height.toStringAsFixed(0)}';

void _useSurface(WidgetTester tester, Size size) {
  tester.view
    ..devicePixelRatio = 3
    ..physicalSize = size * 3;
  addTearDown(tester.view.reset);
  if (size == const Size(844, 390)) {
    tester.view.padding = const FakeViewPadding(
      left: 47 * 3,
      right: 47 * 3,
      bottom: 21 * 3,
    );
    addTearDown(tester.view.resetPadding);
  }
}

BuildContext _page(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first);

Rect _firstMaterialUnder(WidgetTester tester, Finder overlay) => tester.getRect(
  find.descendant(of: overlay, matching: find.byType(Material)).first,
);

Future<void> _close(WidgetTester tester, Finder overlay) async {
  Navigator.of(tester.element(overlay)).pop();
  await tester.pumpAndSettle();
}

void main() {
  final recording = Platform.environment['GUARD_RECORD'] == '1';
  final recorded = <String>[];
  tearDownAll(() {
    // Recording prints the map to paste into _expected.
    // ignore: avoid_print
    if (recording) print(recorded.join('\n'));
  });

  for (final MapEntry(key: platform, value: sizes) in _sizes.entries) {
    for (final size in sizes) {
      testWidgets(
        'nothing moves at ${_name(size)}: the overview, the account tab, '
        'task edit, the task sheet and a long dialog',
        (tester) async {
          void expectRect(String what, Rect rect) {
            final key = '${platform.name} ${_name(size)} $what';
            if (recording) {
              recorded.add(
                "  '$key': Rect.fromLTRB(${rect.left}, ${rect.top}, "
                '${rect.right}, ${rect.bottom}),',
              );
              return;
            }
            final expected = _expected[key];
            expect(expected, isNotNull, reason: 'no rect recorded for $key');
            expect(rect.left, moreOrLessEquals(expected!.left), reason: key);
            expect(rect.top, moreOrLessEquals(expected.top), reason: key);
            expect(rect.right, moreOrLessEquals(expected.right), reason: key);
            expect(rect.bottom, moreOrLessEquals(expected.bottom), reason: key);
          }

          _useSurface(tester, size);
          await pumpSweepApp(tester);
          expectRect(
            'overview card',
            tester.getRect(find.byType(SectionCardItem).first),
          );
          expectRect(
            'overview row',
            tester.getRect(find.byType(TaskRow).first),
          );

          unawaited(showTaskDetail(_page(tester), task: _task(1)));
          await tester.pumpAndSettle();
          if (defaultTargetPlatform == TargetPlatform.iOS) {
            final sheet = find.byType(TaskDetailSheet);
            expectRect('task sheet', tester.getRect(sheet));
            await _close(tester, sheet);
          } else {
            final sheet = find.byType(BottomSheet);
            expectRect('task sheet', _firstMaterialUnder(tester, sheet));
            await _close(tester, sheet);

            unawaited(
              confirmAdaptive(
                _page(tester),
                title: 'Delete the task?',
                body: List.filled(80, 'This cannot be undone.').join(' '),
                confirmLabel: 'Delete',
              ),
            );
            await tester.pumpAndSettle();
            final dialog = find.byType(Dialog);
            expectRect('long dialog', _firstMaterialUnder(tester, dialog));
            await _close(tester, dialog);
          }

          goTo(tester, AppRoutes.account);
          await tester.pumpAndSettle();
          expectRect(
            'account tile',
            tester.getRect(find.byType(ListTile).first),
          );

          pushTo(tester, AppRoutes.taskEdit(1));
          await tester.pumpAndSettle();
          expectRect(
            'task edit field',
            tester.getRect(find.byType(TextField).first),
          );
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(platform),
      );
    }
  }
}

Task _task(int id) => sweepData().tasks.all.firstWhere((task) => task.id == id);
