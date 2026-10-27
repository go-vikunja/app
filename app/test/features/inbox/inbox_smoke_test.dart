import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/background/background_run_log.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/inbox/presentation/inbox_button.dart';
import 'package:vikunja_mobile/features/inbox/presentation/inbox_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';
import 'inbox_samples.dart';

/// The inbox, its bell and the Account tab's new lines at 200 % text on a
/// small phone in dark mode, in both languages and on both platforms, with
/// long names; layout overflows fail the test.
void main() {
  const smallPhone = Size(320, 640);
  const locales = [Locale('en'), Locale('de')];
  const platforms = TargetPlatformVariant({
    TargetPlatform.android,
    TargetPlatform.iOS,
  });

  void useWorstCase(WidgetTester tester, Locale locale) {
    usePhoneSurface(tester, logicalSize: smallPhone);
    useAccessibilityExtremes(tester);
    useLocale(tester, locale);
  }

  Future<void> scrollToEnd(WidgetTester tester, Finder scrollView) async {
    final position = tester
        .state<ScrollableState>(
          find
              .descendant(of: scrollView, matching: find.byType(Scrollable))
              .first,
        )
        .position;
    for (var i = 0; i < 80 && position.extentAfter > 300; i++) {
      await tester.drag(scrollView, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    // A drag past the end bounces on iOS, and the lazily laid-out list then
    // corrects its offset by the bounce again and again, depending on the
    // exact layout; the last stretch therefore jumps.
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(position.extentAfter, 0);
  }

  SyncFakes richData() {
    final now = DateTime.now();
    final doer = payloadUser(
      id: 2,
      username: 'annabelle.example',
      name: 'Annabelle Maximiliane Example-Longname',
    );
    final task = payloadTask(
      id: 40,
      title: 'Water the plants on the balcony before the weekend trip',
      identifier: 'HOUSEHOLD-1234',
    );
    final data = SyncFakes(now: now);
    data.tasks.all = [
      sampleTask(
        id: 40,
        title: 'Water the plants on the balcony before the weekend trip',
      ),
    ];
    data.activity.notifications = [
      for (final (index, name) in [
        'task.comment',
        'task.assigned',
        'task.mentioned',
        'task.created',
        'task.deleted',
        'project.created',
        'team.member.added',
        'task.reminder',
        'migration.done',
      ].indexed)
        inboxNotification(
          id: 100 - index,
          name: name,
          created: now.subtract(Duration(hours: index * 9)),
          readAt: index.isEven ? null : now,
          payload: {
            'doer': doer,
            'task': task,
            'project': {
              'id': 3,
              'title': 'A project with a rather long title indeed',
            },
            'comment': {
              'id': 1,
              'comment':
                  '<p>${'This comment goes on and on about the plants. ' * 4}'
                  '</p>',
            },
            'assignee': payloadUser(id: 3, username: 'bartholomew'),
            'member': payloadUser(id: 3, username: 'bartholomew'),
            'team': {'id': 1, 'name': 'The extended family and neighbours'},
          },
        ),
    ];
    return data;
  }

  for (final locale in locales) {
    testWidgets('bell, inbox and a row’s task (${locale.languageCode})', (
      tester,
    ) async {
      useWorstCase(tester, locale);
      await pumpSignedInApp(tester, sync: richData());
      expect(find.byType(InboxButton), findsOneWidget);

      await tester.tap(find.byType(InboxButton));
      await tester.pumpAndSettle();
      expect(find.byType(InboxScreen), findsOneWidget);
      await scrollToEnd(tester, find.byType(InboxScreen));

      await tester.drag(find.byType(InboxScreen), const Offset(0, 20000));
      await tester.pumpAndSettle();
      // The newest row, the comment.
      await tester.tap(find.textContaining('HOUSEHOLD-1234').first);
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: platforms);

    testWidgets('empty inbox (${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      await pumpSignedInApp(tester);

      await tester.tap(find.byType(InboxButton));
      await tester.pumpAndSettle();

      expect(
        find.text(lookupAppLocalizations(locale).inboxEmptyTitle),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }, variant: platforms);

    testWidgets('account tab with the background line and the activity '
        'switch (${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final auth = AuthFakes();
      final entry = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      );
      await auth.preferences.setString(
        BackgroundRunLog.lastRunAtKey(entry.id),
        DateTime.now()
            .subtract(const Duration(hours: 5))
            .toUtc()
            .toIso8601String(),
      );
      await pumpVikunjaApp(
        tester,
        auth: auth,
        sync: SyncFakes(
          status: SyncFailed(
            failure: const NetworkFailure(NetworkProblem.unreachable),
            lastSyncedAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ),
      );
      await openTab(tester, lookupAppLocalizations(locale).tabAccount);

      await scrollToEnd(tester, find.byType(AccountTab));
      expect(tester.takeException(), isNull);
    }, variant: platforms);
  }
}
