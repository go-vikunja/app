import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

const _milkStart =
    '<li data-checked="false" data-task-id="a1" data-type="taskItem">';
const _milkTicked =
    '<li data-checked="true" data-task-id="a1" data-type="taskItem">';
const _box = '<label><input type="checkbox"><span></span></label>';
const _tickedBox =
    '<label><input type="checkbox" checked="checked"><span></span></label>';
const _milk = '$_milkStart$_box<div><p>Buy milk</p></div></li>';
const _bobStart =
    '<li data-checked="true" data-task-id="b2" data-type="taskItem">';
const _bobText = '<p>Call <a href="https://example.org/bob">Bob</a></p>';
const _bob = '$_bobStart$_tickedBox<div>$_bobText</div></li>';
const _legacy = '<li data-checked="" data-type="taskItem"><p>Old item</p></li>';
const _checklist = '<ul data-type="taskList">$_milk$_bob$_legacy</ul><p></p>';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(id: 1, title: 'Work', identifier: 'WORK'),
      sampleProject(id: 2, title: 'Old', identifier: 'OLD', archived: true),
      sampleProject(id: 3, title: 'Below old', parent: 2),
    ];
    data.tasks.all = [
      sampleTask(id: 1, title: 'Shopping', description: _checklist),
      sampleTask(
        id: 2,
        title: 'Archived shopping',
        projectId: 3,
        description: _checklist,
      ),
    ];
  });

  List<Object?> recordHaptics(WidgetTester tester) {
    final calls = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return calls;
  }

  Future<void> openSheet(WidgetTester tester, String title) async {
    usePhoneSurface(tester, logicalSize: const Size(360, 1800));
    await pumpSignedInApp(tester, sync: data, now: now);
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(TaskDetailSheet), matching: finder);

  Finder unchecked() => inSheet(find.byIcon(Icons.check_box_outline_blank));

  testWidgets('a tap ticks the item in place, with a haptic and an '
      'announcement', (tester) async {
    final haptics = recordHaptics(tester);
    await openSheet(tester, 'Shopping');

    await tester.tap(unchecked());
    await tester.pumpAndSettle();

    final (taskId, item, checked) = data.tasks.checklistToggles.single;
    expect((taskId, checked), (1, true));
    expect(item.sourceOffset, _checklist.indexOf('data-checked="false"'));
    expect(
      data.tasks.find(1)!.description,
      _checklist.replaceFirst('$_milkStart$_box', '$_milkTicked$_tickedBox'),
    );
    expect(unchecked(), findsNothing);
    expect(haptics, ['HapticFeedbackType.selectionClick']);
    expect(tester.takeAnnouncements(), [
      isAccessibilityAnnouncement(en.checklistItemChecked),
    ]);
  });

  testWidgets('a ticked item is unticked the same way', (tester) async {
    await openSheet(tester, 'Shopping');

    await tester.tap(inSheet(find.byIcon(Icons.check_box)).first);
    await tester.pumpAndSettle();

    final (_, item, checked) = data.tasks.checklistToggles.single;
    expect(checked, isFalse);
    expect(item.taskId, 'b2');
    expect(tester.takeAnnouncements(), [
      isAccessibilityAnnouncement(en.checklistItemUnchecked),
    ]);
  });

  testWidgets('a tap the repository refuses (a stale view) changes nothing '
      'and says nothing', (tester) async {
    final haptics = recordHaptics(tester);
    data.tasks.refuseToggles = true;
    await openSheet(tester, 'Shopping');

    await tester.tap(unchecked());
    await tester.pumpAndSettle();

    expect(data.tasks.checklistToggles, hasLength(1));
    expect(data.tasks.find(1)!.description, _checklist);
    expect(unchecked(), findsOneWidget);
    expect(haptics, isEmpty);
    expect(tester.takeAnnouncements(), isEmpty);
  });

  testWidgets('an item that cannot be toggled in place stays read-only', (
    tester,
  ) async {
    await openSheet(tester, 'Shopping');
    final legacy = find.ancestor(
      of: inSheet(find.text('Old item')),
      matching: find.byType(MergeSemantics),
    );

    await tester.tap(
      find.descendant(of: legacy, matching: find.byIcon(Icons.check_box)),
    );
    await tester.pumpAndSettle();

    expect(data.tasks.checklistToggles, isEmpty);
    expect(
      find.descendant(of: legacy, matching: find.byType(InkResponse)),
      findsNothing,
    );
  });

  testWidgets('each item is one checkbox for screen readers; one with a link '
      'keeps the link apart', (tester) async {
    final semantics = tester.ensureSemantics();
    await openSheet(tester, 'Shopping');

    expect(
      tester.getSemantics(inSheet(find.text('Buy milk'))),
      isSemantics(
        hasCheckedState: true,
        isChecked: false,
        hasTapAction: true,
        label: 'Buy milk',
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Call Bob')),
      isSemantics(
        hasCheckedState: true,
        isChecked: true,
        hasTapAction: true,
        label: 'Call Bob',
      ),
    );
    expect(
      tester.getSemantics(inSheet(find.text('Old item'))),
      isSemantics(hasCheckedState: true, isChecked: true, hasTapAction: false),
    );
    semantics.dispose();
  });

  testWidgets('a task whose create is still queued can be ticked', (
    tester,
  ) async {
    data.tasks.all = [
      ...data.tasks.all,
      sampleTask(id: -1, title: 'Not sent yet', description: _checklist),
    ];
    await openSheet(tester, 'Not sent yet');

    await tester.tap(unchecked());
    await tester.pumpAndSettle();

    expect(data.tasks.checklistToggles.single.$1, -1);
  });

  testWidgets('below an archived project the checkboxes take no taps', (
    tester,
  ) async {
    await openSheet(tester, 'Archived shopping');

    await tester.tap(unchecked());
    await tester.pumpAndSettle();

    expect(data.tasks.checklistToggles, isEmpty);
    expect(
      find.ancestor(of: unchecked(), matching: find.byType(InkResponse)),
      findsNothing,
    );
  });

  test('the fixture parses into three items, two of them toggleable', () {
    final items = parseRichText(
      _checklist,
      apiRoot: Uri.parse('https://tasks.example.org'),
      taskLinkBases: const [],
    ).taskItems;
    expect(
      [for (final item in items) item.sourceOffset != null],
      [true, true, false],
    );
  });
}
