import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/avatar_page.dart';
import 'package:vikunja_mobile/features/home/presentation/reauth_banner.dart';

import '../../helpers/account_settings_fakes.dart';
import '../../helpers/announcer_region.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  late AuthFakes auth;
  late SyncFakes data;
  late FakeExternalLinkOpener links;

  FakeAccountSettingsRepository repository() => data.shared.accountSettings;

  setUp(() {
    auth = AuthFakes();
    data = SyncFakes();
    links = FakeExternalLinkOpener();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    AccountSettingsState? state,
    ServerConnection? connection,
    bool needsReauth = false,
    FakeServerConnector? connector,
    List<Override> overrides = const [],
  }) async {
    usePhoneSurface(tester);
    if (state != null) repository().state = state;
    await auth.seedAccount(
      connection ?? fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      needsReauth: needsReauth,
    );
    await pumpVikunjaApp(
      tester,
      auth: auth,
      sync: data,
      linkOpener: links,
      connector: connector,
      overrides: overrides,
    );
    unawaited(
      containerOf(tester)
          .read(appRouterProvider)
          .push(AppRoutes.accountSettings),
    );
    await tester.pumpAndSettle();
  }

  Finder pageList() => find
      .descendant(
        of: find.byType(AccountSettingsPage),
        matching: find.byType(Scrollable),
      )
      .first;

  /// From the top of the page down to [finder], which ends up in the
  /// middle of the screen.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    tester.state<ScrollableState>(pageList()).position.jumpTo(0);
    await tester.pump();
    for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
      await tester.drag(pageList(), const Offset(0, -120));
      await tester.pump();
    }
    await Scrollable.ensureVisible(
      tester.element(finder.first),
      alignment: 0.4,
    );
    await tester.pumpAndSettle();
  }

  /// The text's place in the whole list, scrolled to from where the list
  /// is, so texts further down come after.
  Future<double> placeInList(WidgetTester tester, String text) async {
    final finder = find.text(text);
    for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
      await tester.drag(pageList(), const Offset(0, -120));
      await tester.pump();
    }
    final scrolled = tester.state<ScrollableState>(pageList()).position.pixels;
    return tester.getTopLeft(finder.first).dy + scrolled;
  }

  Future<void> tapRow(WidgetTester tester, String title) async {
    final row = find.widgetWithText(ListTile, title);
    await scrollTo(tester, row);
    await tester.tap(row.first);
    await tester.pumpAndSettle();
  }

  /// Taps the option in the open sheet, below its title.
  Future<void> choose(WidgetTester tester, String label) async {
    final option = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(label),
    );
    await tester.scrollUntilVisible(
      option,
      120,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    await tester.tap(option);
    await tester.pumpAndSettle();
  }

  testWidgets('opens from the profile header, its Edit and its row', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    await pumpVikunjaApp(tester, auth: auth, sync: data);
    await openTab(tester, en.tabAccount);

    await tester.tap(find.text('Alice Example'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountSettingsPage), findsOneWidget);
    expect(find.text(en.accountSettingsIntro('tasks.example.org')), findsOne);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.accountSettingsEntry));
    await tester.pumpAndSettle();
    expect(find.byType(AccountSettingsPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, en.accountHeaderEdit));
    await tester.pumpAndSettle();
    expect(find.byType(AccountSettingsPage), findsOneWidget);
    expect(repository().calls, ['refresh', 'refresh', 'refresh']);
  });

  testWidgets('shows the stored settings in the web order', (tester) async {
    data.projects.all = [sampleProject(id: 1, title: 'Inbox')];
    await pumpPage(
      tester,
      state: fakeAccountSettingsState(
        settings: const UserSettings(
          name: 'Alice Example',
          defaultProjectId: 1,
          weekStart: 1,
          timezone: 'Europe/Berlin',
          language: 'de-DE',
          minimumPriority: 3,
        ),
      ),
    );

    final texts = [
      en.accountSettingsProfile,
      en.accountSettingsSignIn,
      en.accountSettingsDefaults,
      en.projectInboxTitle,
      en.priorityHigh,
      'Monday',
      en.accountSettingsTimeAndLanguage,
      'Europe/Berlin',
      'Deutsch',
      en.accountSettingsEmailNotifications,
      en.accountSettingsPrivacy,
      en.accountSettingsDiscoverableByEmail,
      en.accountSettingsApiTokens,
    ];
    final places = [for (final text in texts) await placeInList(tester, text)];

    for (final (index, place) in places.indexed.skip(1)) {
      expect(
        place,
        greaterThan(places[index - 1]),
        reason: '${texts[index]} after ${texts[index - 1]}',
      );
    }
  });

  testWidgets('leaves the theme to the Account tab', (tester) async {
    await pumpPage(tester);

    final position = tester.state<ScrollableState>(pageList()).position;
    for (var i = 0; i < 60; i++) {
      expect(find.byType(SegmentedButton<ThemeMode>), findsNothing);
      expect(find.text(en.appearanceTheme), findsNothing);
      if (position.extentAfter <= 0) break;
      await tester.drag(pageList(), const Offset(0, -300));
      await tester.pump();
    }
    expect(position.extentAfter, 0);
  });

  testWidgets('saving keeps the page in place, with a named progress bar', (
    tester,
  ) async {
    final saved = Completer<void>();
    repository().beforeCall = (call) async {
      if (call.startsWith('update')) await saved.future;
    };
    await pumpPage(tester);
    final control = find.widgetWithText(
      SwitchListTile,
      en.accountSettingsDiscoverableByName,
    );
    await scrollTo(tester, control);
    final before = tester.getTopLeft(control).dy;

    await tester.tap(control);
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is LinearProgressIndicator &&
            widget.semanticsLabel == en.accountSettingsSaving,
      ),
      findsOneWidget,
    );
    expect(tester.getTopLeft(control).dy, before);
    saved.complete();
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.getTopLeft(control).dy, before);
  });

  group('each control saves its setting', () {
    testWidgets('the name on Done', (tester) async {
      await pumpPage(tester);

      await tester.enterText(
        find.widgetWithText(TextField, en.accountSettingsName),
        '  Alice Wonder ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(repository().changes, [
        const UserSettingsChanges(name: 'Alice Wonder'),
      ]);
      expect(find.text(en.accountSettingsNameSaved), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, en.accountSettingsName),
            )
            .controller!
            .text,
        'Alice Wonder',
      );
    });

    testWidgets('an unsaved name asks before leaving', (tester) async {
      await pumpPage(tester);
      await tester.enterText(
        find.widgetWithText(TextField, en.accountSettingsName),
        'Someone else',
      );
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text(en.accountSettingsNameDiscardBody), findsOneWidget);
      await tester.tap(find.text(en.taskEditDiscard));
      await tester.pumpAndSettle();

      expect(find.byType(AccountSettingsPage), findsNothing);
      expect(repository().changes, isEmpty);
    });

    testWidgets('the default project, none included, archived ones left out', (
      tester,
    ) async {
      data.projects.all = [
        sampleProject(id: 1, title: 'Work'),
        sampleProject(id: 2, title: 'Old', archived: true),
      ];
      await pumpPage(tester);

      await tapRow(tester, en.accountSettingsDefaultProject);
      expect(find.text('Old'), findsNothing);
      await choose(tester, 'Work');
      expect(
        repository().changes.last,
        const UserSettingsChanges(defaultProjectId: SettingChange.set(1)),
      );
      expect(find.text('Work'), findsOneWidget);

      await tapRow(tester, en.accountSettingsDefaultProject);
      await choose(tester, en.accountSettingsDefaultProjectNone);
      expect(
        repository().changes.last,
        const UserSettingsChanges(defaultProjectId: SettingChange.clear()),
      );
    });

    final cases =
        <
          ({
            String name,
            String Function() row,
            String Function() option,
            UserSettingsChanges changes,
            UserSettings settings,
          })
        >[
          (
            name: 'default view',
            row: () => en.accountSettingsDefaultView,
            option: () => en.projectViewKanban,
            changes: const UserSettingsChanges(
              defaultViewKind: SettingChange.set(ProjectViewKind.kanban),
            ),
            settings: const UserSettings(),
          ),
          (
            name: 'first view',
            row: () => en.accountSettingsDefaultView,
            option: () => en.accountSettingsDefaultViewFirst,
            changes: const UserSettingsChanges(
              defaultViewKind: SettingChange.clear(),
            ),
            settings: const UserSettings(defaultViewKind: ProjectViewKind.list),
          ),
          (
            name: 'quick add magic',
            row: () => en.accountSettingsQuickAddMagic,
            option: () => en.accountSettingsQuickAddMagicTodoist,
            changes: const UserSettingsChanges(
              quickAddMagicMode: QuickAddMagicMode.todoist,
            ),
            settings: const UserSettings(),
          ),
          (
            name: 'minimum priority',
            row: () => en.accountSettingsMinimumPriority,
            option: () => en.priorityUrgent,
            changes: const UserSettingsChanges(minimumPriority: 4),
            settings: const UserSettings(),
          ),
          (
            name: 'week start',
            row: () => en.accountSettingsWeekStart,
            option: () => 'Monday',
            changes: const UserSettingsChanges(weekStart: 1),
            settings: const UserSettings(),
          ),
          (
            name: 'date display',
            row: () => en.accountSettingsDateDisplay,
            option: () => en.accountSettingsDateYearMonthDayDashed,
            changes: const UserSettingsChanges(
              dateDisplay: SettingChange.set(DateDisplay.yearMonthDayDashed),
            ),
            settings: const UserSettings(),
          ),
          (
            name: "date display back to the device's",
            row: () => en.accountSettingsDateDisplay,
            option: () => en.accountSettingsDateDisplayDevice,
            changes: const UserSettingsChanges(
              dateDisplay: SettingChange.clear(),
            ),
            settings: const UserSettings(dateDisplay: DateDisplay.relative),
          ),
          (
            name: 'time format',
            row: () => en.accountSettingsTimeFormat,
            option: () => '${en.accountSettingsTimeFormat24} · 14:30',
            changes: const UserSettingsChanges(
              timeFormat: SettingChange.set(TimeFormat.twentyFourHour),
            ),
            settings: const UserSettings(),
          ),
        ];
    for (final testCase in cases) {
      testWidgets('the ${testCase.name}', (tester) async {
        await pumpPage(
          tester,
          state: fakeAccountSettingsState(settings: testCase.settings),
        );

        await tapRow(tester, testCase.row());
        await choose(tester, testCase.option());

        expect(repository().changes, [testCase.changes]);
      });
    }

    testWidgets('the same choice again sends nothing', (tester) async {
      await pumpPage(tester);

      await tapRow(tester, en.accountSettingsQuickAddMagic);
      await choose(tester, en.accountSettingsQuickAddMagicVikunja);

      expect(repository().changes, isEmpty);
    });

    testWidgets("the Overview's saved filter, or all open tasks", (
      tester,
    ) async {
      data.projects.savedFilters = const [
        SavedFilterRef(projectId: -2, title: 'My Open Tasks'),
        SavedFilterRef(projectId: -5, title: 'Urgent'),
      ];
      await pumpPage(tester);

      await tapRow(tester, en.accountSettingsOverviewFilter);
      await choose(tester, en.savedFilterMyOpenTasks);
      expect(
        repository().changes.last,
        const UserSettingsChanges(
          filterIdUsedOnOverview: SettingChange.set(-2),
        ),
      );

      await tapRow(tester, en.accountSettingsOverviewFilter);
      await choose(tester, en.accountSettingsOverviewFilterNone);
      expect(
        repository().changes.last,
        const UserSettingsChanges(
          filterIdUsedOnOverview: SettingChange.clear(),
        ),
      );
    });

    testWidgets('the time zone from a searched list', (tester) async {
      await pumpPage(tester);

      await tapRow(tester, en.accountSettingsTimezone);
      // Which zones are suggested depends on where the tests run.
      final suggestedHeading = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data == en.accountSettingsTimezoneDevice ||
                widget.data == en.accountSettingsTimezoneSameAsDevice),
      );
      expect(suggestedHeading, findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, en.accountSettingsTimezoneSearch),
        'America/New_York',
      );
      await tester.pumpAndSettle();
      expect(find.text('America/New York'), findsOneWidget);
      expect(suggestedHeading, findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, en.accountSettingsTimezoneSearch),
        'kolkata',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asia/Kolkata'));
      await tester.pumpAndSettle();

      expect(repository().changes, [
        const UserSettingsChanges(timezone: 'Asia/Kolkata'),
      ]);
      expect(find.text('Asia/Kolkata'), findsOneWidget);
    });

    testWidgets('the language from the web list', (tester) async {
      await pumpPage(tester);

      await tapRow(tester, en.accountSettingsLanguage);
      await tester.enterText(
        find.widgetWithText(TextField, en.accountSettingsLanguageSearch),
        'deu',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();

      expect(repository().changes, [
        const UserSettingsChanges(language: 'de-DE'),
      ]);
    });

    testWidgets('the email switches, the summary time only while it is on', (
      tester,
    ) async {
      await pumpPage(
        tester,
        state: fakeAccountSettingsState(
          settings: const UserSettings(timeFormat: TimeFormat.twentyFourHour),
        ),
      );

      final reminders = find.widgetWithText(
        SwitchListTile,
        en.accountSettingsEmailReminders,
      );
      await scrollTo(tester, reminders);
      await tester.tap(reminders);
      await tester.pumpAndSettle();
      expect(
        repository().changes.last,
        const UserSettingsChanges(emailRemindersEnabled: true),
      );

      await tapRow(tester, en.accountSettingsOverdueTime);
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), '7');
      await tester.enterText(fields.at(1), '30');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(
        repository().changes.last,
        const UserSettingsChanges(overdueTasksRemindersTime: ClockTime(7, 30)),
      );
      expect(find.text('07:30'), findsOneWidget);

      final overdue = find.widgetWithText(
        SwitchListTile,
        en.accountSettingsOverdueReminders,
      );
      await scrollTo(tester, overdue);
      await tester.tap(overdue);
      await tester.pumpAndSettle();
      expect(
        repository().changes.last,
        const UserSettingsChanges(overdueTasksRemindersEnabled: false),
      );
      expect(find.text(en.accountSettingsOverdueTime), findsNothing);
    });

    testWidgets('both privacy switches', (tester) async {
      await pumpPage(tester);

      for (final title in [
        en.accountSettingsDiscoverableByName,
        en.accountSettingsDiscoverableByEmail,
      ]) {
        final control = find.widgetWithText(SwitchListTile, title);
        await scrollTo(tester, control);
        await tester.tap(control);
        await tester.pumpAndSettle();
      }

      expect(repository().changes, const [
        UserSettingsChanges(discoverableByName: true),
        UserSettingsChanges(discoverableByEmail: true),
      ]);
    });
  });

  group('refusals', () {
    testWidgets('an unknown time zone is shown at its row', (tester) async {
      repository().failures['update'] = const DomainError(400, code: 1025);
      await pumpPage(tester);

      await tapRow(tester, en.accountSettingsTimezone);
      await tester.enterText(
        find.widgetWithText(TextField, en.accountSettingsTimezoneSearch),
        'kolkata',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asia/Kolkata'));
      await tester.pumpAndSettle();

      expect(
        find.text(en.accountSettingsTimezoneInvalid('Asia/Kolkata')),
        findsOneWidget,
      );
      expect(find.text(en.accountSettingsTimezoneServerDefault), findsOne);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a default project the server refuses', (tester) async {
      data.projects.all = [sampleProject(id: 1, title: 'Shared')];
      repository().failures['update'] = const DomainError(400, code: 3017);
      await pumpPage(tester);

      await tapRow(tester, en.accountSettingsDefaultProject);
      await choose(tester, 'Shared');

      expect(
        find.text(en.accountSettingsDefaultProjectInvalid),
        findsOneWidget,
      );
      expect(find.text(en.accountSettingsDefaultProjectNone), findsOneWidget);
    });

    group('reach a screen reader', () {
      const invalid = ValidationFailed(
        code: 2002,
        fieldErrors: {
          'name': ['invalid'],
        },
      );

      Future<void> saveName(WidgetTester tester) async {
        await tester.enterText(
          find.widgetWithText(TextField, en.accountSettingsName),
          'Alice',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
      }

      testWidgets('through the platform where it announces', (tester) async {
        repository().failures['update'] = invalid;
        await pumpPage(tester);

        await saveName(tester);

        expect(tester.takeAnnouncements(), [
          isAccessibilityAnnouncement(en.accountSettingsInvalid),
        ]);
      });

      testWidgets('without platform announcements, as on Android, a refused '
          "name through its field's live region alone", (tester) async {
        useLiveRegionAnnouncements(tester);
        repository().failures['update'] = invalid;
        await pumpPage(tester);

        await saveName(tester);

        expect(tester.takeAnnouncements(), isEmpty);
        expect(announcerRegion(tester)?.label, '');
        final error = tester
            .getSemantics(find.text(en.accountSettingsInvalid))
            .getSemanticsData();
        expect(error.flagsCollection.isLiveRegion, isTrue);
      });

      testWidgets('without platform announcements, a refused default '
          "project, whose error is no live region, through the announcer's "
          'live region', (tester) async {
        useLiveRegionAnnouncements(tester);
        data.projects.all = [sampleProject(id: 1, title: 'Shared')];
        repository().failures['update'] = const DomainError(400, code: 3017);
        await pumpPage(tester);

        await tapRow(tester, en.accountSettingsDefaultProject);
        await choose(tester, 'Shared');

        expect(
          announcerRegion(tester)?.label,
          en.accountSettingsDefaultProjectInvalid,
        );
      });
    });

    testWidgets('a summary time the server refuses', (tester) async {
      repository().failures['update'] = const ValidationFailed(
        code: 2002,
        fieldErrors: {
          'overdue_tasks_reminders_time': ['does not validate as time'],
        },
      );
      await pumpPage(
        tester,
        state: fakeAccountSettingsState(
          settings: const UserSettings(timeFormat: TimeFormat.twentyFourHour),
        ),
      );

      await tapRow(tester, en.accountSettingsOverdueTime);
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), '8');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text(en.accountSettingsOverdueTimeInvalid), findsOneWidget);
    });

    testWidgets('no connection says so, reverts and makes the page read-only', (
      tester,
    ) async {
      repository().failures['update'] = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await pumpPage(tester);

      final control = find.widgetWithText(
        SwitchListTile,
        en.accountSettingsDiscoverableByName,
      );
      await scrollTo(tester, control);
      await tester.tap(control);
      await tester.pumpAndSettle();

      expect(find.text(en.accountSettingsNeedsConnection), findsOneWidget);
      expect(tester.widget<SwitchListTile>(control).value, isFalse);
      expect(tester.widget<SwitchListTile>(control).onChanged, isNull);
      await scrollTo(tester, find.text(en.accountSettingsOffline));
      expect(find.text(en.accountSettingsOffline), findsOneWidget);
    });

    testWidgets('a lost answer may have been saved', (tester) async {
      repository().failures['update'] = const NetworkFailure(
        NetworkProblem.timeout,
      );
      await pumpPage(tester);

      final control = find.widgetWithText(
        SwitchListTile,
        en.accountSettingsDiscoverableByEmail,
      );
      await scrollTo(tester, control);
      await tester.tap(control);
      await tester.pumpAndSettle();

      expect(find.text(en.accountSettingsUnconfirmed), findsOneWidget);
    });
  });

  group('offline', () {
    testWidgets('after a sync that could not reach the server, only shows', (
      tester,
    ) async {
      data = SyncFakes(
        status: SyncFailed(
          failure: const NetworkFailure(NetworkProblem.unreachable),
          lastSyncedAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );
      data.engine.onRefresh = () async =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      data.shared.accountSettings.failures['refresh'] = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await pumpPage(tester);

      expect(find.text(en.accountSettingsOffline), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, en.accountSettingsName),
            )
            .enabled,
        isFalse,
      );
      await tapRow(tester, en.accountSettingsDefaultView);
      expect(find.byType(BottomSheet), findsNothing);
      expect(repository().changes, isEmpty);
    });

    testWidgets('a refresh that gets through counts more than the last sync', (
      tester,
    ) async {
      data = SyncFakes(
        status: SyncFailed(
          failure: const NetworkFailure(NetworkProblem.unreachable),
          lastSyncedAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );
      final refresh = Completer<void>();
      data.engine.onRefresh = () async =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      data.shared.accountSettings.beforeCall = (call) async {
        if (call == 'refresh') await refresh.future;
      };
      await pumpPage(tester);
      expect(find.text(en.accountSettingsOffline), findsOneWidget);

      refresh.complete();
      await tester.pumpAndSettle();

      expect(find.text(en.accountSettingsOffline), findsNothing);
    });

    testWidgets('a refresh that cannot reach the server, until a retry does', (
      tester,
    ) async {
      repository().failures['refresh'] = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await pumpPage(tester);
      expect(find.text(en.accountSettingsOffline), findsOneWidget);

      repository().failures.remove('refresh');
      await tester.tap(find.text(en.retry));
      await tester.pumpAndSettle();

      expect(find.text(en.accountSettingsOffline), findsNothing);
    });
  });

  testWidgets('before the profile is read, nothing only a local account can '
      'change is offered', (tester) async {
    await pumpPage(
      tester,
      state: const AccountSettingsState(
        settings: UserSettings(name: 'Alice Example'),
        avatarProvider: AvatarProvider.initials,
      ),
    );

    final name = tester.widget<TextField>(
      find.widgetWithText(TextField, en.accountSettingsName),
    );
    expect(name.enabled, isFalse);
    expect(find.text(en.accountSettingsWaitingForProfile), findsNWidgets(2));
    expect(find.text(en.accountSettingsChangePassword), findsNothing);
    expect(find.text(en.accountSettingsChangeEmail), findsNothing);

    repository().state = fakeAccountSettingsState();
    await tester.pumpAndSettle();

    expect(find.text(en.accountSettingsWaitingForProfile), findsNothing);
    expect(find.text(en.accountSettingsChangePassword), findsOneWidget);
  });

  testWidgets('a session that ended offers to sign in again', (tester) async {
    auth.serveUser(
      const User(id: 7, username: 'alice', name: 'Alice Example'),
      now: DateTime.now().toUtc(),
    );
    await pumpPage(
      tester,
      needsReauth: true,
      connector: FakeServerConnector.succeeding(fullServer270()),
    );
    expect(find.text(en.accountSettingsSignInAgain), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, en.accountSettingsName),
          )
          .enabled,
      isFalse,
    );

    await tester.tap(find.widgetWithText(TextButton, en.reauthAction));
    await tester.pumpAndSettle();

    expect(auth.webAuthenticator.urls, hasLength(1));
    expect(find.text(en.accountSettingsSignInAgain), findsNothing);
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, en.accountSettingsName),
          )
          .enabled,
      isTrue,
    );
  });

  group('accounts of a sign-in provider', () {
    for (final (provider, shown) in [
      ('Keycloak', 'Keycloak'),
      ('ldap', 'LDAP'),
    ]) {
      testWidgets('$provider: the name and password are managed there', (
        tester,
      ) async {
        await pumpPage(
          tester,
          state: fakeAccountSettingsState(
            isLocalUser: false,
            authProvider: provider,
          ),
        );

        final name = tester.widget<TextField>(
          find.widgetWithText(TextField, en.accountSettingsName),
        );
        expect(name.enabled, isFalse);
        expect(find.text(en.accountSettingsNameManaged(shown)), findsOne);
        expect(find.text(en.accountSettingsChangePassword), findsNothing);
        expect(find.text(en.accountSettingsChangeEmail), findsNothing);
        await scrollTo(
          tester,
          find.text(en.accountSettingsManagedBySignInNamed(shown)),
        );
        expect(
          find.text(en.accountSettingsManagedBySignInNamed(shown)),
          findsOneWidget,
        );
      });
    }
  });

  group('password and email on the web', () {
    testWidgets('open the web pages in the browser', (tester) async {
      await pumpPage(tester);

      await tapRow(tester, en.accountSettingsChangePassword);
      await tapRow(tester, en.accountSettingsChangeEmail);

      expect(links.opened, [
        Uri.parse(
          'https://tasks.example.org/vikunja/user/settings/password-update',
        ),
        Uri.parse(
          'https://tasks.example.org/vikunja/user/settings/email-update',
        ),
      ]);
    });

    testWidgets('a pending email change is shown', (tester) async {
      await pumpPage(
        tester,
        state: fakeAccountSettingsState(pendingEmail: 'new@example.org'),
      );

      expect(
        find.text(en.accountSettingsPendingEmail('new@example.org')),
        findsOneWidget,
      );
    });

    testWidgets('a browser that does not open says so', (tester) async {
      links = FakeExternalLinkOpener(succeeds: false);
      await pumpPage(tester);

      await tapRow(tester, en.accountSettingsChangeEmail);

      expect(find.text(en.accountSettingsWebNotOpened), findsOneWidget);
    });

    void resume(WidgetTester tester) => [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);

    testWidgets('back from the password page the session is checked at once '
        'and a changed password asks to sign in again', (tester) async {
      auth.tokenGateway.onRefresh = (_) async => throw const SessionEnded(
        SessionEndReason.invalidRefreshToken,
        code: 16002,
      );
      await pumpPage(tester);

      await tapRow(tester, en.accountSettingsChangePassword);
      expect(auth.tokenGateway.refreshedTokens, isEmpty);
      resume(tester);
      // The session manager looks for a sibling's rotation for a few
      // seconds before it gives a 16002 up.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pumpAndSettle();

      expect(auth.tokenGateway.refreshedTokens, hasLength(1));
      final entry = containerOf(tester).read(accountsProvider).value!;
      expect(entry.activeAccount!.account.needsReauth, isTrue);
      expect(find.text(en.accountSettingsSignInAgain), findsOneWidget);
      // The page asks the server again for a pending email.
      expect(
        repository().calls.where((call) => call == 'refresh'),
        hasLength(2),
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      await openTab(tester, en.tabAccount);
      expect(find.byType(ReauthBanner), findsOneWidget);
    });

    testWidgets('back from the email page the session is not refreshed', (
      tester,
    ) async {
      await pumpPage(tester);

      await tapRow(tester, en.accountSettingsChangeEmail);
      resume(tester);
      await tester.pumpAndSettle();

      expect(auth.tokenGateway.refreshedTokens, isEmpty);
    });
  });

  testWidgets('the avatar row opens the avatar page', (tester) async {
    await pumpPage(tester);

    expect(find.text(en.avatarProviderInitials), findsOneWidget);
    await tester.tap(find.text(en.accountSettingsAvatar));
    await tester.pumpAndSettle();

    expect(find.byType(AvatarPage), findsOneWidget);
  });

  testWidgets('is in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await pumpPage(tester);

    expect(find.text(de.accountSettingsTitle), findsOneWidget);
    expect(find.text(de.accountSettingsProfile), findsOneWidget);
  });
}
