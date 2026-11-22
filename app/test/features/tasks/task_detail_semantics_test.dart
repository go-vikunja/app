import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [sampleProject(id: 1, title: 'Work')];
    data.tasks.all = [
      sampleTask(
        id: 1,
        title: 'Quarterly report',
        due: DateTime(2026, 10, 12, 9, 30),
        priority: TaskPriority.high,
        labels: [sampleLabel(id: 1, title: 'Finance')],
        description: [
          '<ul data-type="taskList">',
          '<li data-checked="true"><p>Collect</p></li>',
          '<li data-checked="false"><p>Sum up</p></li>',
          '<li data-checked="false"><p>Send</p></li>',
          '</ul>',
        ].join(),
      ),
    ];
  });

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(TaskDetailSheet), matching: finder);

  Future<void> openSheet(WidgetTester tester) async {
    usePhoneSurface(tester, logicalSize: const Size(400, 2400));
    await pumpSignedInApp(tester, sync: data, now: now);
    await tester.tap(find.text('Quarterly report'));
    await tester.pumpAndSettle();
  }

  List<SemanticsNode> childrenOf(SemanticsNode node) =>
      node.debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder);

  testWidgets('the attribute card starts with the due date, and Labels is a '
      'node of its own after the rows above it, holding its buttons', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openSheet(tester);

    final due = tester.getSemantics(
      inSheet(find.text(en.taskDetailDueDateRow)),
    );
    final card = due.parent!;
    expect(card.label, isEmpty);
    final rows = childrenOf(card);
    expect(rows.first, same(due));

    final labels = tester.getSemantics(inSheet(find.text(en.taskDetailLabels)));
    expect(labels.label, en.taskDetailLabels);
    expect(labels.parent, same(card));
    final priority = tester.getSemantics(
      inSheet(find.text(en.taskDetailPriority)),
    );
    expect(rows.indexOf(labels), greaterThan(rows.indexOf(priority)));
    expect(
      tester
          .getSemantics(inSheet(find.byTooltip(en.taskDetailChangeLabels)))
          .parent,
      same(labels),
    );
    semantics.dispose();
  });

  testWidgets('the description heading is "Description" alone, and the '
      'checklist summary follows it as plain text, without a progress bar', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openSheet(tester);

    final heading = tester.getSemantics(
      inSheet(find.text(en.taskDetailDescription)),
    );
    expect(
      heading,
      isSemantics(label: en.taskDetailDescription, isHeader: true),
    );
    expect(heading.getSemanticsData().headingLevel, 2);
    expect(heading.value, isEmpty);
    expect(heading.role, isNot(SemanticsRole.progressBar));

    final summary = tester.getSemantics(
      inSheet(find.text(en.taskChecklistChecked(1, 3))),
    );
    expect(summary, isNot(same(heading)));
    expect(summary, isSemantics(label: en.taskChecklistChecked(1, 3)));
    expect(summary.flagsCollection.isHeader, isFalse);
    expect(summary.value, isEmpty);
    final siblings = childrenOf(heading.parent!);
    expect(siblings.indexOf(summary), siblings.indexOf(heading) + 1);
    semantics.dispose();
  });

  testWidgets('the star and the bell are switches whose names stay the '
      'same as their state changes, never also selected', (tester) async {
    final semantics = tester.ensureSemantics();
    await openSheet(tester);

    SemanticsNode star() =>
        tester.getSemantics(inSheet(find.byTooltip(en.taskAddFavourite)));
    expect(
      star(),
      isSemantics(
        label: en.favouriteLabel,
        isButton: true,
        hasToggledState: true,
        isToggled: false,
        hasTapAction: true,
      ),
    );
    expect(star().flagsCollection.isSelected, isNot(Tristate.isTrue));
    expect(star().tooltip, isEmpty);

    final bell = tester.getSemantics(inSheet(find.byTooltip(en.followTask)));
    expect(
      bell,
      isSemantics(
        label: en.followTask,
        hasToggledState: true,
        isToggled: false,
        hasTapAction: true,
      ),
    );
    expect(bell.flagsCollection.isSelected, isNot(Tristate.isTrue));
    expect(bell.tooltip, isEmpty);

    await tester.tap(inSheet(find.byTooltip(en.taskAddFavourite)));
    await tester.pumpAndSettle();

    final on = tester.getSemantics(
      inSheet(find.byTooltip(en.taskRemoveFavourite)),
    );
    expect(
      on,
      isSemantics(
        label: en.favouriteLabel,
        hasToggledState: true,
        isToggled: true,
      ),
    );
    expect(on.flagsCollection.isSelected, isNot(Tristate.isTrue));
    semantics.dispose();
  });
}
