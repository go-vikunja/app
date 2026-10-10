import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/web_authenticator.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/home/presentation/reauth_banner.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connection_error_card.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/fake_read_client.dart';
import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';
import '../helpers/sample_data.dart';
import '../helpers/server_connections.dart';

// Layout overflows are reported as test failures, so reaching the end of each
// scenario without an exception is the assertion.
void main() {
  const smallPhone = Size(320, 640);
  const locales = [Locale('en'), Locale('de')];

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
    for (var i = 0; i < 50 && position.extentAfter > 0; i++) {
      await tester.drag(scrollView, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(position.extentAfter, 0);
  }

  FakeReadClient richData() {
    final now = DateTime.now();
    final label = sampleLabel(
      id: 1,
      title: 'A rather long label title',
      hexColor: 'ffeb10',
    );
    final client = FakeReadClient();
    client.projects.all = [
      sampleProject(
        id: 1,
        title: 'Work with a very long project title',
        favorite: true,
        hexColor: '1973ff',
      ),
      sampleProject(
        id: 2,
        title: 'Child project with another long title',
        parent: 1,
      ),
    ];
    client.tasks.openTasks = [
      for (var i = 1; i <= 6; i++)
        sampleTask(
          id: i,
          title: 'Task $i with a title long enough to wrap onto several lines',
          due: i == 6 ? null : now.add(Duration(days: i * 3 - 5)),
          identifier: 'LONGIDENT-$i',
          priority: TaskPriority.doNow,
          labels: [label, label],
          favorite: true,
          assignees: const [
            User(
              id: 1,
              username: 'maximiliane',
              name: 'Maximiliane Musterfrau-Beispielhausen',
            ),
          ],
          reminders: const [
            TaskReminder(
              relativePeriod: Duration(hours: -1),
              relativeTo: ReminderRelativeTo.dueDate,
            ),
          ],
          repeatAfter: const Duration(days: 14),
          percentDone: 0.5,
          description:
              '<p>Some description text that is long enough to wrap.</p>',
        ),
    ];
    client.tasks.projectTasks = {1: client.tasks.openTasks};
    client.tasks.perPage = 4;
    return client;
  }

  for (final locale in locales) {
    testWidgets('overview with tasks at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      await pumpSignedInApp(tester, readClient: richData());

      await scrollToEnd(tester, find.byType(CustomScrollView));
      expect(tester.takeException(), isNull);
    });

    testWidgets('task detail sheet at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      await pumpSignedInApp(tester, readClient: richData());

      await tester.tap(find.textContaining('Task 1 ').first);
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailSheet), findsOneWidget);
      await scrollToEnd(tester, find.byType(TaskDetailSheet));
      expect(tester.takeException(), isNull);
    });

    testWidgets('project tree and project tasks at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      await pumpSignedInApp(tester, readClient: richData());
      final l10n = lookupAppLocalizations(locale);

      await openTab(tester, l10n.tabProjects);
      await scrollToEnd(tester, find.byType(CustomScrollView));
      expect(tester.takeException(), isNull);

      containerOf(tester).read(appRouterProvider).go(AppRoutes.project(1));
      await tester.pumpAndSettle();
      await scrollToEnd(tester, find.byType(CustomScrollView));
      expect(tester.takeException(), isNull);
    });

    testWidgets('overview failure states at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final client = richData();
      client.tasks.onList = (_) async =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      await pumpSignedInApp(tester, readClient: client);
      expect(find.byType(DataFailureCard), findsOneWidget);
      await scrollToEnd(tester, find.byType(CustomScrollView));

      client.tasks.onList = null;
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      client.tasks.onList = (_) async => throw const ServerFailure(502);
      await pullToRefresh(tester, find.byType(CustomScrollView));

      expect(find.byType(DataFailureCard), findsOneWidget);
      await scrollToEnd(tester, find.byType(CustomScrollView));
      expect(tester.takeException(), isNull);
    });

    testWidgets('connect screen with an error at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final connector = FakeServerConnector.failing(
        BehindLoginProxy(Uri.parse('https://a-rather-long-host.example.org')),
      );
      await pumpVikunjaApp(tester, connector: connector);

      final context = tester.element(find.byType(Scaffold).first);
      expect(MediaQuery.textScalerOf(context).scale(10), 20);
      expect(Theme.of(context).brightness, Brightness.dark);

      await tester.enterText(
        find.byType(TextFormField),
        'a-rather-long-host.example.org',
      );
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionErrorCard), findsOneWidget);
      await scrollToEnd(tester, find.byType(SingleChildScrollView).first);
      expect(tester.takeException(), isNull);
    });

    testWidgets('connecting state at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final pending = Completer<ServerConnection>();
      await pumpVikunjaApp(
        tester,
        connector: FakeServerConnector((_) => pending.future),
      );

      await tester.enterText(
        find.byType(TextFormField),
        'a-rather-long-host.example.org',
      );
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('http confirmation at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      await pumpVikunjaApp(
        tester,
        connector: FakeServerConnector.succeeding(insecureServer()),
      );

      await tester.enterText(find.byType(TextFormField), '192.168.1.20:3456');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((w) => w is AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    final l10n = lookupAppLocalizations(locale);
    for (final (name, connection, primaryAction) in [
      ('full', fullServer270(), l10n.continueToSignIn),
      ('unsupported', legacyServer100(), l10n.useDifferentServer),
    ]) {
      testWidgets('$name overview in landscape at 200 % leaves room to read '
          '(${locale.languageCode})', (tester) async {
        const landscape = Size(800, 360);
        usePhoneSurface(tester, logicalSize: landscape);
        useAccessibilityExtremes(tester);
        useLocale(tester, locale);
        await pumpServerOverview(tester, connection);

        expect(
          tester.getSize(find.byType(ListView)).height,
          greaterThanOrEqualTo(landscape.height * 0.75),
        );

        await scrollToEnd(tester, find.byType(ListView));
        final action = tester.getRect(
          find.widgetWithText(FilledButton, primaryAction),
        );
        expect(action.bottom, lessThanOrEqualTo(landscape.height));
        expect(tester.takeException(), isNull);
      });
    }

    for (final (name, connection) in [
      ('full', fullServer270(demoMode: true)),
      ('insecure', insecureServer()),
      ('unsupported', legacyServer100()),
    ]) {
      testWidgets('$name overview at 200 % in dark mode '
          '(${locale.languageCode})', (tester) async {
        useWorstCase(tester, locale);
        await pumpServerOverview(tester, connection);

        await scrollToEnd(tester, find.byType(ListView));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('overview with a sign-in failure at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final auth = AuthFakes();
      auth.tokenGateway.onExchange = (_) async =>
          throw const RateLimited(retryAfter: Duration(minutes: 3));
      await pumpServerOverview(tester, fullServer270(), auth: auth);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionErrorCard), findsOneWidget);
      await scrollToEnd(tester, find.byType(ListView));
      expect(tester.takeException(), isNull);
    });

    testWidgets('home with an ended session and a failed retry at 200 % in '
        'dark mode (${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final auth = AuthFakes();
      await auth.seedAccount(
        fullServer270(root: 'https://a-rather-long-host.example.org/vikunja'),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
        displayName: 'Maximiliane Musterfrau-Beispielhausen',
        needsReauth: true,
      );
      auth.webAuthenticator.handler = (_, _) async =>
          throw const WebAuthenticationFailed(
            WebAuthenticationProblem.noBrowser,
          );
      await pumpVikunjaApp(
        tester,
        auth: auth,
        connector: FakeServerConnector.failing(StateError('offline')),
      );
      await openTab(tester, l10n.tabAccount);

      expect(find.byType(ReauthBanner), findsOneWidget);
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionErrorCard), findsOneWidget);
      await scrollToEnd(tester, find.byType(ListView));
      expect(tester.takeException(), isNull);
    });

    testWidgets('sign-out dialog at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final auth = AuthFakes();
      await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      );
      await pumpVikunjaApp(tester, auth: auth);
      await openTab(tester, l10n.tabAccount);

      await scrollToEnd(tester, find.byType(ListView));
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((w) => w is AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
