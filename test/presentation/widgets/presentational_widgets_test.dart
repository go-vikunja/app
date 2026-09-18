/// Stateless building blocks: what they render for a given input, and the
/// callbacks the tappable ones fire. Screens that compose them assert only
/// composition, never these details.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vikunja_app/core/theming/app_colors.dart';
import 'package:vikunja_app/core/utils/misc.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';
import 'package:vikunja_app/presentation/pages/project/expansion_title.dart';
import 'package:vikunja_app/presentation/widgets/button.dart';
import 'package:vikunja_app/presentation/widgets/due_date_card.dart';
import 'package:vikunja_app/presentation/widgets/empty_view.dart';
import 'package:vikunja_app/presentation/widgets/label_widget.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/bucket_feedback.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/kanban_task_item.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/priority_batch.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/task_feedback.dart';

import '../../helpers/builders.dart';
import '../../helpers/test_app.dart';

void main() {
  setUpAll(loadL10n);

  group('FancyButton', () {
    testWidgets('renders its child', (tester) async {
      await pumpApp(
        tester,
        const FancyButton(child: Text('Save')),
        inScaffold: true,
      );

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('tapping it fires onPressed', (tester) async {
      var pressed = false;

      await pumpApp(
        tester,
        FancyButton(onPressed: () => pressed = true, child: const Text('Save')),
        inScaffold: true,
      );
      await tapAndSettle(tester, find.text('Save'));

      expect(pressed, isTrue);
    });

    testWidgets('is disabled without an onPressed', (tester) async {
      await pumpApp(
        tester,
        const FancyButton(child: Text('Save')),
        inScaffold: true,
      );

      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
    });
  });

  group('EmptyView', () {
    testWidgets('shows the icon and message it was given', (tester) async {
      await pumpApp(
        tester,
        const EmptyView(Icons.list, 'Nothing here yet'),
        inScaffold: true,
      );

      expect(find.byIcon(Icons.list), findsOneWidget);
      expect(find.text('Nothing here yet'), findsOneWidget);
    });
  });

  group('LoadingWidget', () {
    testWidgets('shows a spinner and the loading label', (tester) async {
      await pumpApp(tester, const LoadingWidget(), inScaffold: true);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.loading), findsOneWidget);
    });
  });

  group('DueDateCard', () {
    testWidgets('describes a future date as a relative interval', (
      tester,
    ) async {
      final due = DateTime.now().add(const Duration(days: 3));

      await pumpApp(tester, DueDateCard(due), inScaffold: true);

      expect(find.textContaining('in '), findsOneWidget);
      expect(find.textContaining('days'), findsOneWidget);
    });

    testWidgets('describes a past date as overdue', (tester) async {
      final due = DateTime.now().subtract(const Duration(days: 2));

      await pumpApp(tester, DueDateCard(due), inScaffold: true);

      expect(find.textContaining('ago'), findsOneWidget);
    });

    testWidgets('an overdue card uses the error colour', (tester) async {
      final due = DateTime.now().subtract(const Duration(days: 2));

      await pumpApp(tester, DueDateCard(due), inScaffold: true);

      final context = tester.element(find.byType(DueDateCard));
      final card = tester.widget<Card>(find.byType(Card));
      expect(card.color, Theme.of(context).colorScheme.errorContainer);
    });

    testWidgets('an upcoming card uses the neutral surface colour', (
      tester,
    ) async {
      final due = DateTime.now().add(const Duration(days: 2));

      await pumpApp(tester, DueDateCard(due), inScaffold: true);

      final context = tester.element(find.byType(DueDateCard));
      final card = tester.widget<Card>(find.byType(Card));
      expect(card.color, Theme.of(context).colorScheme.surfaceContainerHighest);
    });

    testWidgets('renders the same text the shared formatter produces', (
      tester,
    ) async {
      // Pinned, so the card and the expectation measure from the same moment.
      final now = DateTime(2026, 3, 10, 9);
      final due = now.add(const Duration(hours: 5));

      await withClock(Clock.fixed(now), () async {
        await pumpApp(tester, DueDateCard(due), inScaffold: true);
      });

      expect(
        find.text(durationToHumanReadable(const Duration(hours: 5))),
        findsOneWidget,
      );
    });
  });

  group('LabelWidget', () {
    testWidgets('shows the label title', (tester) async {
      await pumpApp(
        tester,
        LabelWidget(label: buildLabel(title: 'Bug')),
        inScaffold: true,
      );

      expect(find.text('Bug'), findsOneWidget);
    });

    testWidgets('uses the label colour as its background', (tester) async {
      await pumpApp(
        tester,
        LabelWidget(label: buildLabel(color: const Color(0xFF112233))),
        inScaffold: true,
      );

      expect(
        tester.widget<Chip>(find.byType(Chip)).backgroundColor,
        const Color(0xFF112233),
      );
    });

    testWidgets('uses white text on a dark label', (tester) async {
      await pumpApp(
        tester,
        LabelWidget(label: buildLabel(color: const Color(0xFF000000))),
        inScaffold: true,
      );

      expect(tester.widget<Text>(find.text('Bug')).style!.color, Colors.white);
    });

    testWidgets('uses black text on a light label', (tester) async {
      await pumpApp(
        tester,
        LabelWidget(label: buildLabel(color: const Color(0xFFFFFFFF))),
        inScaffold: true,
      );

      expect(tester.widget<Text>(find.text('Bug')).style!.color, Colors.black);
    });

    testWidgets('leaves the text colour to the theme when uncoloured', (
      tester,
    ) async {
      await pumpApp(
        tester,
        LabelWidget(label: buildLabel(color: null)),
        inScaffold: true,
      );

      expect(tester.widget<Text>(find.text('Bug')).style!.color, isNull);
    });

    testWidgets('shows no delete affordance without an onDelete', (
      tester,
    ) async {
      await pumpApp(tester, LabelWidget(label: buildLabel()), inScaffold: true);

      expect(tester.widget<Chip>(find.byType(Chip)).onDeleted, isNull);
    });

    testWidgets('tapping the delete affordance fires onDelete', (tester) async {
      var deleted = false;

      await pumpApp(
        tester,
        LabelWidget(label: buildLabel(), onDelete: () => deleted = true),
        inScaffold: true,
      );
      await tapAndSettle(tester, find.byIcon(Icons.cancel));

      expect(deleted, isTrue);
    });
  });

  group('PriorityBatch', () {
    testWidgets('names each priority level', (tester) async {
      for (final (priority, label) in [
        (1, l10n.priorityLow),
        (2, l10n.priorityMedium),
        (3, l10n.priorityHigh),
        (4, l10n.priorityUrgent),
        (5, l10n.priorityDoNow),
      ]) {
        await pumpApp(tester, PriorityBatch(priority), inScaffold: true);

        expect(find.text(label), findsOneWidget, reason: 'priority $priority');
      }
    });

    testWidgets('renders nothing readable for the unset priority', (
      tester,
    ) async {
      await pumpApp(tester, PriorityBatch(0), inScaffold: true);

      expect(find.text(l10n.priorityUnset), findsOneWidget);
    });

    testWidgets('colours low, medium and high differently', (tester) async {
      Color? backgroundFor(int priority) {
        final badge = tester.widget<Badge>(find.byType(Badge));
        return badge.backgroundColor;
      }

      await pumpApp(tester, PriorityBatch(1), inScaffold: true);
      final low = backgroundFor(1);
      await pumpApp(tester, PriorityBatch(2), inScaffold: true);
      final medium = backgroundFor(2);
      await pumpApp(tester, PriorityBatch(4), inScaffold: true);
      final urgent = backgroundFor(4);

      expect(low, isNotNull);
      expect(medium, isNotNull);
      expect(urgent, isNotNull);
      expect({low, medium, urgent}, hasLength(3));
    });

    testWidgets('leaves the unset priority uncoloured', (tester) async {
      await pumpApp(tester, PriorityBatch(0), inScaffold: true);

      expect(tester.widget<Badge>(find.byType(Badge)).backgroundColor, isNull);
    });

    testWidgets('falls back to fixed colours without the theme extension', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const <ThemeExtension<dynamic>>[]),
          locale: const Locale('en'),
          localizationsDelegates: const [...[]],
          home: const SizedBox(),
        ),
      );

      // Exercised directly: the widget's colour helpers must not require the
      // AppColors extension to be present.
      const batch = PriorityBatch(1);
      final context = tester.element(find.byType(SizedBox));
      expect(batch.getBackgroundColor(context, 1), Colors.green);
      expect(batch.getBackgroundColor(context, 2), Colors.yellow);
      expect(batch.getBackgroundColor(context, 3), Colors.red);
      expect(batch.getBackgroundColor(context, 0), isNull);
      expect(batch.getBackgroundColor(context, 99), isNull);
      expect(batch.getTextColor(context, 1), Colors.green);
      expect(batch.getTextColor(context, 2), Colors.yellow);
      expect(batch.getTextColor(context, 5), Colors.red);
      expect(batch.getTextColor(context, 0), isNull);
      expect(batch.getTextColor(context, 99), isNull);
    });

    testWidgets('prefers the semantic colours from the theme extension', (
      tester,
    ) async {
      const appColors = AppColors(
        success: Color(0xFF010101),
        onSuccess: Color(0xFF020202),
        warning: Color(0xFF030303),
        onWarning: Color(0xFF040404),
        danger: Color(0xFF050505),
        onDanger: Color(0xFF060606),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [appColors]),
          home: const SizedBox(),
        ),
      );

      const batch = PriorityBatch(1);
      final context = tester.element(find.byType(SizedBox));
      expect(batch.getBackgroundColor(context, 1), appColors.success);
      expect(batch.getBackgroundColor(context, 2), appColors.warning);
      expect(batch.getBackgroundColor(context, 5), appColors.danger);
      expect(batch.getTextColor(context, 1), appColors.onSuccess);
      expect(batch.getTextColor(context, 2), appColors.onWarning);
      expect(batch.getTextColor(context, 3), appColors.onDanger);
    });
  });

  group('TaskFeedback', () {
    testWidgets('shows the dragged task title', (tester) async {
      await pumpApp(
        tester,
        const TaskFeedback(title: 'Dragging me'),
        inScaffold: true,
      );

      expect(find.text('Dragging me'), findsOneWidget);
      expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
    });
  });

  group('BucketFeedback', () {
    testWidgets('shows the bucket title', (tester) async {
      await pumpApp(
        tester,
        BucketFeedback(bucket: buildBucket(title: 'Doing')),
        inScaffold: true,
      );

      expect(find.text('Doing'), findsOneWidget);
    });

    testWidgets('previews at most three of the bucket tasks', (tester) async {
      await pumpApp(
        tester,
        BucketFeedback(
          bucket: buildBucket(
            tasks: List.generate(5, (i) => buildTask(id: i, title: 'Task $i')),
          ),
        ),
        inScaffold: true,
      );

      expect(find.byType(Chip), findsNWidgets(3));
      expect(find.text('Task 3'), findsNothing);
    });

    testWidgets('previews nothing for an empty bucket', (tester) async {
      await pumpApp(
        tester,
        BucketFeedback(bucket: buildBucket(tasks: [])),
        inScaffold: true,
      );

      expect(find.byType(Chip), findsNothing);
    });
  });

  group('kanban TaskTile', () {
    testWidgets('shows the identifier and title', (tester) async {
      await pumpApp(
        tester,
        TaskTile(
          task: buildTask(identifier: '#12', title: 'Ship it'),
        ),
        inScaffold: true,
      );

      expect(find.text('#12'), findsOneWidget);
      expect(find.text('Ship it'), findsOneWidget);
    });

    testWidgets('badges a done task', (tester) async {
      await pumpApp(
        tester,
        TaskTile(task: buildTask(done: true)),
        inScaffold: true,
      );

      expect(find.text(l10n.badgeDone), findsOneWidget);
    });

    testWidgets('does not badge an open task', (tester) async {
      await pumpApp(
        tester,
        TaskTile(task: buildTask(done: false)),
        inScaffold: true,
      );

      expect(find.text(l10n.badgeDone), findsNothing);
    });

    testWidgets('shows a due date card when the task has one', (tester) async {
      await pumpApp(
        tester,
        TaskTile(
          task: buildTask(dueDate: DateTime.now().add(const Duration(days: 1))),
        ),
        inScaffold: true,
      );

      expect(find.byType(DueDateCard), findsOneWidget);
    });

    testWidgets('omits the due date card for the year-1 sentinel', (
      tester,
    ) async {
      await pumpApp(
        tester,
        TaskTile(task: buildTask(dueDate: DateTime.utc(1))),
        inScaffold: true,
      );

      expect(find.byType(DueDateCard), findsNothing);
    });

    testWidgets('shows a priority badge above low priority', (tester) async {
      await pumpApp(
        tester,
        TaskTile(task: buildTask(priority: 3)),
        inScaffold: true,
      );

      expect(find.byType(PriorityBatch), findsOneWidget);
    });

    testWidgets('omits the priority badge at or below low priority', (
      tester,
    ) async {
      await pumpApp(
        tester,
        TaskTile(task: buildTask(priority: 1)),
        inScaffold: true,
      );

      expect(find.byType(PriorityBatch), findsNothing);
    });

    testWidgets('shows the task labels', (tester) async {
      await pumpApp(
        tester,
        TaskTile(
          task: buildTask(labels: [buildLabel(title: 'Bug')]),
        ),
        inScaffold: true,
      );

      expect(find.byType(LabelWidget), findsOneWidget);
      expect(find.text('Bug'), findsOneWidget);
    });

    testWidgets('hints at a description with a notes icon', (tester) async {
      await pumpApp(
        tester,
        TaskTile(task: buildTask(description: 'Some detail')),
        inScaffold: true,
      );

      expect(find.byIcon(Icons.notes), findsOneWidget);
    });

    testWidgets('shows no notes icon without a description', (tester) async {
      await pumpApp(
        tester,
        TaskTile(task: buildTask(description: '')),
        inScaffold: true,
      );

      expect(find.byIcon(Icons.notes), findsNothing);
    });

    testWidgets('uses the task colour as the card background', (tester) async {
      await pumpApp(
        tester,
        TaskTile(task: buildTask(color: const Color(0xFF112233))),
        inScaffold: true,
      );

      expect(
        tester.widget<Card>(find.byType(Card).first).color,
        const Color(0xFF112233),
      );
    });

    testWidgets('falls back to the surface colour when uncoloured', (
      tester,
    ) async {
      await pumpApp(
        tester,
        TaskTile(task: buildTask(color: null)),
        inScaffold: true,
      );

      final context = tester.element(find.byType(TaskTile));
      expect(
        tester.widget<Card>(find.byType(Card).first).color,
        Theme.of(context).colorScheme.surface,
      );
    });
  });

  group('VikunjaExpansionTile', () {
    testWidgets('starts collapsed with its children hidden', (tester) async {
      await pumpApp(
        tester,
        const VikunjaExpansionTile(
          title: Text('Parent'),
          children: [Text('Child')],
        ),
        inScaffold: true,
      );

      expect(find.text('Parent'), findsOneWidget);
      expect(find.text('Child'), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);
    });

    testWidgets('tapping the chevron expands it', (tester) async {
      await pumpApp(
        tester,
        const VikunjaExpansionTile(
          title: Text('Parent'),
          children: [Text('Child')],
        ),
        inScaffold: true,
      );

      await tapAndSettle(tester, find.byIcon(Icons.keyboard_arrow_right));

      expect(find.text('Child'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });

    testWidgets('tapping the chevron again collapses it', (tester) async {
      await pumpApp(
        tester,
        const VikunjaExpansionTile(
          title: Text('Parent'),
          children: [Text('Child')],
        ),
        inScaffold: true,
      );

      await tapAndSettle(tester, find.byIcon(Icons.keyboard_arrow_right));
      await tapAndSettle(tester, find.byIcon(Icons.keyboard_arrow_down));

      expect(find.text('Child'), findsNothing);
    });

    testWidgets('tapping the title fires onTitleTap', (tester) async {
      var tapped = false;

      await pumpApp(
        tester,
        VikunjaExpansionTile(
          title: const Text('Parent'),
          onTitleTap: () => tapped = true,
          children: const [Text('Child')],
        ),
        inScaffold: true,
      );
      await tapAndSettle(tester, find.text('Parent'));

      expect(tapped, isTrue);
    });
  });

  group('VikunjaErrorWidget', () {
    testWidgets('renders a plain string error as-is', (tester) async {
      await pumpApp(
        tester,
        const VikunjaErrorWidget(error: 'Something broke'),
        inScaffold: true,
      );

      expect(find.text('Something broke'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('explains a connection failure in plain language', (
      tester,
    ) async {
      await pumpApp(
        tester,
        VikunjaErrorWidget(error: http.ClientException('refused')),
        inScaffold: true,
      );

      expect(find.text(l10n.connectionError), findsOneWidget);
    });

    testWidgets('explains a timeout in plain language', (tester) async {
      await pumpApp(
        tester,
        VikunjaErrorWidget(error: TimeoutException('slow')),
        inScaffold: true,
      );

      expect(find.text(l10n.connectionTimeout), findsOneWidget);
    });

    testWidgets('unwraps a nested AsyncError', (tester) async {
      await pumpApp(
        tester,
        VikunjaErrorWidget(
          error: AsyncError<void>(
            http.ClientException('refused'),
            StackTrace.empty,
          ),
        ),
        inScaffold: true,
      );

      expect(find.text(l10n.connectionError), findsOneWidget);
    });

    testWidgets('falls back to toString for anything else', (tester) async {
      await pumpApp(
        tester,
        VikunjaErrorWidget(error: StateError('nope')),
        inScaffold: true,
      );

      expect(find.textContaining('nope'), findsOneWidget);
    });

    testWidgets('shows no retry button without an onRetry', (tester) async {
      await pumpApp(
        tester,
        const VikunjaErrorWidget(error: 'boom'),
        inScaffold: true,
      );

      expect(find.text(l10n.retry), findsNothing);
    });

    testWidgets('tapping Retry fires onRetry', (tester) async {
      var retried = false;

      await pumpApp(
        tester,
        VikunjaErrorWidget(error: 'boom', onRetry: () => retried = true),
        inScaffold: true,
      );
      await tapAndSettle(tester, find.text(l10n.retry));

      expect(retried, isTrue);
    });

    testWidgets('tapping the secondary action fires it', (tester) async {
      var acted = false;

      await pumpApp(
        tester,
        VikunjaErrorWidget(
          error: 'boom',
          onSecondaryAction: () => acted = true,
          secondaryActionLabel: 'Log out',
        ),
        inScaffold: true,
      );
      await tapAndSettle(tester, find.text('Log out'));

      expect(acted, isTrue);
    });

    testWidgets('labels the secondary action Login by default', (tester) async {
      await pumpApp(
        tester,
        VikunjaErrorWidget(error: 'boom', onSecondaryAction: () {}),
        inScaffold: true,
      );

      expect(find.text(l10n.login), findsOneWidget);
    });
  });
}
