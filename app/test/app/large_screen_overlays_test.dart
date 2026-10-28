import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/layout/readable_sheet.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/layout/window_layout.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/features/common/presentation/day_picker.dart';
import 'package:vikunja_mobile/features/common/presentation/day_range_picker.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/cupertino_picker_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/date_time_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/time_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../a11y/sweep_data.dart';
import '../helpers/large_screens.dart';
import '../helpers/pump_app.dart';

const _android = TargetPlatformVariant({TargetPlatform.android});
const _iOS = TargetPlatformVariant({TargetPlatform.iOS});

/// An iPad 13" in landscape, split 50/50.
const _iPadHalf = Size(683, 1024);
const _iPadMiniPortrait = Size(744, 1133);

/// The text of a call's own arguments from its opening parenthesis at
/// [open], without the nested calls and closures.
String _topLevelArguments(String source, int open) {
  final own = StringBuffer();
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final char = source[i];
    if ('([{'.contains(char)) depth++;
    if (')]}'.contains(char)) depth--;
    if (depth == 0) break;
    if (depth == 1) own.write(char);
  }
  return own.toString();
}

BuildContext _page(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first);

ClipRSuperellipse _sheetClip(WidgetTester tester) => tester.widget(
  find
      .descendant(
        of: find.byType(ReadableSheetWidth).last,
        matching: find.byType(ClipRSuperellipse),
      )
      .first,
);

Task _task(int id) => sweepData().tasks.all.firstWhere((task) => task.id == id);

Future<void> _confirm(WidgetTester tester, String body) async {
  unawaited(
    confirmAdaptive(
      _page(tester),
      title: 'Delete the task?',
      body: body,
      confirmLabel: 'Delete',
    ),
  );
  await tester.pumpAndSettle();
}

final String _longBody = List.filled(80, 'This cannot be undone.').join(' ');

/// A sheet of [ReadableSheetWidth] over a plain page, its list long enough
/// to scroll.
Future<void> _showListSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showReadableCupertinoSheet<void>(
                context: context,
                showDragHandle: true,
                scrollableBuilder: (context, controller) => ColoredBox(
                  color: const Color(0xFFFFFFFF),
                  child: ListView.builder(
                    controller: controller,
                    itemCount: 100,
                    itemBuilder: (context, index) =>
                        SizedBox(height: 48, child: Text('Row $index')),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  group('Material dialogs', () {
    testWidgets('are at most 560 wide on a tablet, and at least 280', (
      tester,
    ) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);

      await _confirm(tester, _longBody);
      expect(dialogRect(tester).width, ReadableWidth.dialog);
      Navigator.of(tester.element(find.byType(Dialog))).pop();
      await tester.pumpAndSettle();

      await _confirm(tester, 'Sure?');
      expect(
        dialogRect(tester).width,
        inInclusiveRange(
          ReadableWidth.defaultDialogConstraints.minWidth,
          ReadableWidth.dialog,
        ),
      );
      expect(tester.takeException(), isNull);
    }, variant: _android);

    testWidgets('keep the width they had on a phone in landscape', (
      tester,
    ) async {
      useWindow(tester, androidLandscape);
      await pumpSweepApp(tester);

      await _confirm(tester, _longBody);
      expect(dialogRect(tester).width, androidLandscape.width - 80);
    }, variant: _android);

    testWidgets('the landscape time picker keeps its own width', (
      tester,
    ) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);

      unawaited(
        pickTimeOfDay(
          _page(tester),
          initial: const TimeOfDay(hour: 9, minute: 30),
          display: const DisplaySettings(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);
      expect(dialogRect(tester).width, 572);
      expect(tester.takeException(), isNull);
    }, variant: _android);

    for (final locale in const [Locale('en'), Locale('de')]) {
      testWidgets('the date picker keeps its own width at 200 % text '
          '(${locale.languageCode})', (tester) async {
        useWindow(tester, androidTabletLandscape);
        useAccessibilityExtremes(tester);
        useLocale(tester, locale);
        await pumpSweepApp(tester);

        unawaited(
          pickDateTime(
            _page(tester),
            current: sweepNow,
            now: sweepNow,
            display: const DisplaySettings(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(DatePickerDialog), findsOneWidget);
        expect(dialogRect(tester).width, 992);
        expect(tester.takeException(), isNull);
      }, variant: _android);
    }

    for (final (name, open) in <(String, void Function(BuildContext))>[
      (
        'a day',
        (context) => unawaited(
          pickDay(
            context,
            initial: sweepNow,
            first: DateTime(2000),
            last: DateTime(2100),
            now: sweepNow,
          ),
        ),
      ),
      (
        'a range of days',
        (context) => unawaited(
          pickDayRange(
            context,
            first: sweepNow,
            last: sweepNow,
            now: sweepNow,
            firstDayOfWeekIndex: null,
          ),
        ),
      ),
    ]) {
      testWidgets('the date picker for $name keeps its own width at 200 % '
          'text', (tester) async {
        useWindow(tester, androidTabletLandscape);
        useAccessibilityExtremes(tester);
        await pumpSweepApp(tester);

        open(_page(tester));
        await tester.pumpAndSettle();

        expect(find.byType(DatePickerDialog), findsOneWidget);
        expect(dialogRect(tester).width, greaterThan(ReadableWidth.dialog));
        expect(tester.takeException(), isNull);
      }, variant: _android);
    }
  });

  for (final size in androidSizes) {
    testWidgets('at ${sizeName(size)} a long dialog is 560 wide at most on a '
        'tablet and window less 80 otherwise, a Material sheet 640 at '
        'most', (tester) async {
      useWindow(tester, size);
      await pumpSweepApp(tester);

      await _confirm(tester, _longBody);
      final caps = WindowLayout(size).capsWidths;
      expect(
        dialogRect(tester).width,
        caps ? ReadableWidth.dialog : size.width - 80,
      );
      Navigator.of(tester.element(find.byType(Dialog))).pop();
      await tester.pumpAndSettle();

      unawaited(showTaskDetail(_page(tester), task: _task(1)));
      await tester.pumpAndSettle();
      expect(
        bottomSheetRect(tester).width,
        math.min(size.width, materialSheetMaxWidth),
      );
    }, variant: _android);
  }

  testWidgets('the Material task sheet keeps its cap of 640 on a tablet', (
    tester,
  ) async {
    useWindow(tester, androidTabletLandscape);
    await pumpSweepApp(tester);

    unawaited(showTaskDetail(_page(tester), task: _task(1)));
    await tester.pumpAndSettle();

    expect(bottomSheetRect(tester).width, materialSheetMaxWidth);
    expect(bottomSheetRect(tester).center.dx, androidTabletLandscape.width / 2);
  }, variant: _android);

  group('iOS sheets', () {
    for (final (size, left, right) in [
      (iPad13Portrait, 192.0, 832.0),
      (iPad11Landscape, 277.0, 917.0),
      (iPad11Portrait, 97.0, 737.0),
    ]) {
      testWidgets('the task sheet is a centred card of 640 on an iPad at '
          '${sizeName(size)}, its Mark as done button inside', (tester) async {
        useWindow(tester, size);
        await pumpSweepApp(tester);

        unawaited(showTaskDetail(_page(tester), task: _task(1)));
        await tester.pumpAndSettle();

        final card = tester.getRect(find.byType(TaskDetailSheet));
        expect(iOSSheetContentRect(tester), card);
        expect(
          (card.left, card.right, card.bottom),
          (left, right, size.height),
        );
        expect(_sheetClip(tester).clipBehavior, Clip.antiAlias);
        final done = tester.getRect(
          find.ancestor(
            of: find.text(en.taskDetailMarkDone),
            matching: find.byType(FilledButton),
          ),
        );
        expect(done.width, lessThanOrEqualTo(ReadableWidth.sheet));
        expectInBand(done, (left: card.left, right: card.right));
        expect(tester.takeException(), isNull);
      }, variant: _iOS);
    }

    // At 683 the margins would be 21.5.
    for (final size in [iPhone, iPhoneLandscape, defaultSurface, _iPadHalf]) {
      testWidgets('fill the width, unclipped, at ${sizeName(size)}', (
        tester,
      ) async {
        useWindow(tester, size);
        await pumpSweepApp(tester);

        unawaited(showTaskDetail(_page(tester), task: _task(1)));
        await tester.pumpAndSettle();

        final card = iOSSheetContentRect(tester);
        expect((card.left, card.right), (0, size.width));
        expect(tester.getRect(find.byType(TaskDetailSheet)), card);
        expect(_sheetClip(tester).borderRadius, BorderRadius.zero);
        expect(_sheetClip(tester).clipBehavior, Clip.none);
      }, variant: _iOS);
    }

    testWidgets('a card with margins of at least '
        '${ReadableSheetWidth.minMargin} on an iPad mini in portrait', (
      tester,
    ) async {
      useWindow(tester, _iPadMiniPortrait);
      await pumpSweepApp(tester);

      unawaited(showTaskDetail(_page(tester), task: _task(1)));
      await tester.pumpAndSettle();

      final card = iOSSheetContentRect(tester);
      expect((card.left, card.right), (52, 692));
      expect(_sheetClip(tester).clipBehavior, Clip.antiAlias);
    }, variant: _iOS);

    testWidgets('close on a downward drag on the card, and its list still '
        'scrolls', (tester) async {
      useWindow(tester, iPad13Portrait);
      await _showListSheet(tester);
      expect(iOSSheetContentRect(tester).width, ReadableWidth.sheet);

      final list = find.descendant(
        of: find.byType(ReadableSheetWidth),
        matching: find.byType(Scrollable),
      );
      await tester.drag(list, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(list).position.pixels,
        greaterThan(0),
      );
      tester.state<ScrollableState>(list).position.jumpTo(0);
      await tester.pump();

      await tester.drag(list, const Offset(0, 700));
      await tester.pumpAndSettle();
      expect(find.byType(ReadableSheetWidth), findsNothing);
    }, variant: _iOS);

    testWidgets('close on a downward drag in the margin beside the card', (
      tester,
    ) async {
      useWindow(tester, iPad13Portrait);
      await _showListSheet(tester);

      await tester.dragFrom(const Offset(96, 600), const Offset(0, 700));
      await tester.pumpAndSettle();
      expect(find.byType(ReadableSheetWidth), findsNothing);
    }, variant: _iOS);

    testWidgets("the wheel popup's Cancel and Done lie in its card", (
      tester,
    ) async {
      useWindow(tester, iPad13Portrait);
      await pumpSweepApp(tester);

      unawaited(
        showCupertinoPickerSheet(
          _page(tester),
          mode: CupertinoDatePickerMode.dateAndTime,
          initial: sweepNow,
          use24Hour: true,
        ),
      );
      await tester.pumpAndSettle();

      final card = iOSSheetContentRect(tester);
      expect((card.left, card.right), (192, 832));
      expect(card.bottom, iPad13Portrait.height);
      for (final label in [en.pickerCancel, en.pickerDone]) {
        expectInBand(tester.getRect(find.text(label)), (
          left: card.left,
          right: card.right,
        ));
      }
      expect(tester.takeException(), isNull);
    }, variant: _iOS);
  });

  test("no Material bottom sheet changes M3's cap of 640: neither the "
      'theme nor a call sets constraints', () {
    for (final theme in [
      AppTheme.light(),
      AppTheme.dark(),
      AppTheme.highContrastLight(),
      AppTheme.highContrastDark(),
    ]) {
      expect(theme.bottomSheetTheme.constraints, isNull);
    }
    final calls = RegExp(r'\bshowModalBottomSheet\s*(<.*?>)?\(');
    var found = 0;
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final call in calls.allMatches(source)) {
        found++;
        expect(
          _topLevelArguments(source, call.end - 1),
          isNot(contains('constraints:')),
          reason: file.path,
        );
      }
    }
    expect(found, 11);
  });

  test('every Material date and time picker is built by '
      'pickerFormatsBuilder, which lifts the dialog cap', () {
    final calls = RegExp(r'\bshow(Date|DateRange|Time)Picker\s*(<.*?>)?\(');
    final builder = RegExp(r'\bbuilder:\s*(\w+)');
    var found = 0;
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final call in calls.allMatches(source)) {
        found++;
        final where = '${file.path} at ${call.start}';
        final name = builder
            .firstMatch(_topLevelArguments(source, call.end - 1))
            ?.group(1);
        expect(name, isNotNull, reason: where);
        if (name == 'pickerFormatsBuilder') continue;
        // A local of the same function, assigned from it.
        final declared = source
            .substring(0, call.start)
            .lastIndexOf('final $name = pickerFormatsBuilder(');
        expect(declared, isNot(-1), reason: where);
        expect(
          source.substring(declared, call.start),
          isNot(matches(RegExp(r'\n[^\s}]'))),
          reason: '$where: $name is declared in another function',
        );
      }
    }
    expect(found, 6);
  });

  test('every iOS sheet goes through the presenter, and every bottom popup '
      'through the width', () {
    final sheetCalls = RegExp(r'\bshowCupertinoSheet\s*(<.*?>)?\(');
    final popupCalls = RegExp(r'\bshowCupertinoModalPopup\s*(<.*?>)?\(');
    final wrappers = RegExp(r'\bReadableSheetWidth\(');
    final sheets = <String>[];
    final popups = <String, (int, int)>{};
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final _ in sheetCalls.allMatches(source)) {
        sheets.add(file.path);
      }
      final calls = popupCalls.allMatches(source).length;
      if (calls > 0) {
        popups[file.path] = (calls, wrappers.allMatches(source).length);
      }
    }

    expect(sheets, ['lib/app/layout/readable_sheet.dart']);
    expect(popups, isNotEmpty);
    for (final MapEntry(key: path, value: (calls, wrapped)) in popups.entries) {
      expect(wrapped, calls, reason: path);
    }
  });
}
