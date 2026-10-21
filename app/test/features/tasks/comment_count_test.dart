import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/board_card.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_meta.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeAccountIdProvider.overrideWithValue(null)],
        child: MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: Scaffold(body: ListView(children: [child])),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget row(Task task) => TaskRow(
    task: task,
    now: now,
    minimumPriority: 2,
    onTap: () {},
    onDoneChanged: (_) {},
  );

  Widget card(Task task) =>
      BoardCard(task: task, now: now, minimumPriority: 2, onTap: () {});

  for (final (name, build) in [('task row', row), ('board card', card)]) {
    group('the $name', () {
      testWidgets('shows the comment count, muted while read', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(
          tester,
          build(sampleTask(id: 7, title: 'Pay the bill', commentCount: 3)),
        );

        final count = tester.widget<CommentCount>(find.byType(CommentCount));
        expect(count.count, 3);
        expect(count.unread, isFalse);
        final colors = Theme.of(tester.element(find.text('3'))).colorScheme;
        expect(
          tester.widget<Text>(find.text('3')).style?.color,
          colors.onSurfaceVariant,
        );
        expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
        expect(
          tester.getSemantics(find.text('Pay the bill')).label.split('\n'),
          contains(en.taskCommentCount(3)),
        );
        semantics.dispose();
      });

      testWidgets('in the primary colour with a dot while one is unread', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pump(
          tester,
          build(
            sampleTask(
              id: 7,
              title: 'Pay the bill',
              commentCount: 1,
              isUnread: true,
            ),
          ),
        );

        final colors = Theme.of(tester.element(find.text('1'))).colorScheme;
        expect(
          tester.widget<Text>(find.text('1')).style?.color,
          colors.primary,
        );
        expect(find.byKey(const ValueKey('unread-dot')), findsOneWidget);
        final label = tester.getSemantics(find.text('Pay the bill')).label;
        expect(label.split('\n'), contains(en.taskCommentCountUnread(1)));
        expect(label.split('\n'), isNot(contains(en.taskCommentCount(1))));
        semantics.dispose();
      });

      testWidgets('shows nothing without comments', (tester) async {
        await pump(tester, build(sampleTask(id: 7, title: 'Pay the bill')));

        expect(find.byType(CommentCount), findsNothing);
      });

      testWidgets('fits at 200 % text in dark mode, in German too', (
        tester,
      ) async {
        usePhoneSurface(tester, logicalSize: const Size(320, 640));
        useAccessibilityExtremes(tester);
        useLocale(tester, const Locale('de'));
        await pump(
          tester,
          build(
            sampleTask(
              id: 7,
              title: 'Die Rechnung bezahlen',
              commentCount: 128,
              isUnread: true,
              due: now,
              labels: [sampleLabel(id: 1, title: 'Finanzen')],
            ),
          ),
        );

        expect(find.byType(CommentCount), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
