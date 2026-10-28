import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_meta.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';

void main() {
  Future<ThemeData> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: Scaffold(body: Center(child: child)),
      ),
    );
    return Theme.of(tester.element(find.byType(Scaffold)));
  }

  Color? textColor(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  Icon iconOf(WidgetTester tester, Type widget) => tester.widget<Icon>(
    find.descendant(of: find.byType(widget), matching: find.byType(Icon)),
  );

  group('priority flag', () {
    testWidgets('urgent and up in the error colour', (tester) async {
      final theme = await pump(
        tester,
        const PriorityFlag(priority: TaskPriority.doNow),
      );

      expect(textColor(tester, en.priorityDoNow), theme.colorScheme.error);
      expect(iconOf(tester, PriorityFlag).icon, Icons.flag);
    });

    testWidgets('high with the amber flag', (tester) async {
      final theme = await pump(
        tester,
        const PriorityFlag(priority: TaskPriority.high),
      );

      expect(textColor(tester, en.priorityHigh), theme.colorScheme.tertiary);
      expect(
        iconOf(tester, PriorityFlag).color,
        theme.extension<HighlightColors>()!.highlight,
      );
    });

    testWidgets('lower ones muted and outlined', (tester) async {
      final theme = await pump(
        tester,
        const PriorityFlag(priority: TaskPriority.medium),
      );

      expect(
        textColor(tester, en.priorityMedium),
        theme.colorScheme.onSurfaceVariant,
      );
      expect(iconOf(tester, PriorityFlag).icon, Icons.outlined_flag);
    });

    testWidgets('reads as the priority', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, const PriorityFlag(priority: TaskPriority.urgent));

      expect(
        find.bySemanticsLabel(en.prioritySemantics(en.priorityUrgent)),
        findsOneWidget,
      );
      semantics.dispose();
    });

    test('shows on a row from the minimum priority, never when done', () {
      final high = sampleTask(id: 1, title: 'a', priority: TaskPriority.high);
      expect(PriorityFlag.showsOnRow(high, minimumPriority: 3), isTrue);
      expect(PriorityFlag.showsOnRow(high, minimumPriority: 4), isFalse);
      expect(
        PriorityFlag.showsOnRow(
          sampleTask(
            id: 1,
            title: 'a',
            priority: TaskPriority.high,
            done: true,
          ),
          minimumPriority: 1,
        ),
        isFalse,
      );
      expect(
        PriorityFlag.showsOnRow(
          sampleTask(id: 1, title: 'a'),
          minimumPriority: 0,
        ),
        isFalse,
      );
      expect(PriorityFlag.showsInDetail(TaskPriority.medium), isFalse);
      expect(PriorityFlag.showsInDetail(TaskPriority.high), isTrue);
    });
  });

  group('due', () {
    final now = DateTime(2026, 10, 13, 9);

    test('the tone says overdue, later today, another day or done', () {
      DueTone toneOf(DateTime? due, {bool done = false}) => DueTone.of(
        sampleTask(id: 1, title: 'a', due: due, done: done),
        now: now,
      );
      expect(toneOf(now.subtract(const Duration(minutes: 1))), DueTone.overdue);
      expect(toneOf(now.add(const Duration(hours: 8))), DueTone.today);
      expect(toneOf(DateTime(2026, 10, 14, 0, 30)), DueTone.later);
      expect(
        toneOf(now.subtract(const Duration(days: 2)), done: true),
        DueTone.done,
      );
      expect(toneOf(null), DueTone.done);
    });

    for (final (tone, role) in [
      (DueTone.overdue, (ColorScheme colors) => colors.error),
      (DueTone.today, (ColorScheme colors) => colors.primary),
      (DueTone.later, (ColorScheme colors) => colors.onSurfaceVariant),
      (DueTone.done, (ColorScheme colors) => colors.onSurfaceVariant),
    ]) {
      testWidgets('the badge colours $tone', (tester) async {
        final theme = await pump(
          tester,
          DueBadge(text: 'Tomorrow', tone: tone),
        );

        final expected = role(theme.colorScheme);
        expect(textColor(tester, 'Tomorrow'), expected);
        expect(iconOf(tester, DueBadge).color, expected);
      });
    }

    for (final (tone, icon) in [
      (DueTone.overdue, Icons.error_outline),
      (DueTone.today, Icons.calendar_today_outlined),
      (DueTone.later, Icons.calendar_today_outlined),
      (DueTone.done, Icons.calendar_today_outlined),
    ]) {
      testWidgets('the badge marks $tone with its icon, not only a colour', (
        tester,
      ) async {
        await pump(tester, DueBadge(text: 'Tomorrow', tone: tone));

        expect(iconOf(tester, DueBadge).icon, icon);
      });
    }
  });

  group('label pill', () {
    testWidgets('keeps the label colour with readable text', (tester) async {
      await pump(
        tester,
        Column(
          children: [
            LabelPill(
              label: sampleLabel(id: 1, title: 'Sun', hexColor: 'ffeb10'),
            ),
            LabelPill(
              label: sampleLabel(id: 2, title: 'Night', hexColor: '1d2a6b'),
            ),
          ],
        ),
      );

      expect(textColor(tester, 'Sun'), const Color(0xFF000000));
      expect(textColor(tester, 'Night'), const Color(0xFFFFFFFF));
    });

    testWidgets('without a colour in the secondary container colours', (
      tester,
    ) async {
      final theme = await pump(
        tester,
        LabelPill(label: sampleLabel(id: 1, title: 'Plain')),
      );

      expect(
        textColor(tester, 'Plain'),
        theme.colorScheme.onSecondaryContainer,
      );
      final box = tester.widget<DecoratedBox>(
        find.ancestor(
          of: find.text('Plain'),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        (box.decoration as BoxDecoration).color,
        theme.colorScheme.secondaryContainer,
      );
    });
  });
}
