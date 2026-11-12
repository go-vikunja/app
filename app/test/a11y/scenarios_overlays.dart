import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/avatar_crop_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/default_project_picker.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/one_time_secret_view.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_switcher_sheet.dart';
import 'package:vikunja_mobile/features/accounts/presentation/remove_account_dialog.dart';
import 'package:vikunja_mobile/features/common/presentation/day_range_picker.dart';
import 'package:vikunja_mobile/features/common/presentation/option_sheet.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/delete_task_dialog.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/attribute_editors.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/assignee_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/date_time_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/label_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/project_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/time_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/attachment_image_viewer.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_write_feedback.dart';
import 'package:vikunja_mobile/features/trash/presentation/trash_feedback.dart';

import '../features/account_settings/avatar_fakes.dart';
import '../features/teams/organise_harness.dart';
import '../helpers/auth_fakes.dart';
import '../helpers/guest_app.dart';
import '../helpers/pump_app.dart';
import '../helpers/sync_fakes.dart';
import '../helpers/task_details_fakes.dart';
import 'sweep_data.dart';
import 'sweep_harness.dart';

/// The overlays the sweep opens, by name, and the full-screen pages the
/// app pushes with the Navigator. The overlay inventory assigns every
/// dialog, sheet, menu and page-route call in `app/lib` one of these or a
/// written exemption; removing one here is a visible change there.
const overlayRegistry = <String>[
  'detail sheet',
  'new-task sheet',
  'new-task sheet, more options',
  'account switcher',
  'date-time picker',
  'time picker',
  'day-range picker',
  'project picker',
  'label picker',
  'reminders sheet',
  'assignee picker',
  'default-project picker',
  'option sheet',
  'delete-task dialog',
  'sign-out dialog',
  'done snackbar',
  'bin snackbar',
  'one-time secret page',
  'avatar crop page',
  'image viewer',
];

Finder _byTypeName(String name) =>
    find.byWidgetPredicate((widget) => widget.runtimeType.toString() == name);

BuildContext _page(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first);

/// [show] opens the overlay from a page of the signed-in app, over the
/// Overview; the future it returns is left pending.
SweepScenario _overlay(
  String id, {
  required void Function(BuildContext context, WidgetTester tester) show,
  required ScreenFinder expectScreen,
  SweepStep? after,
  SweepStep? tearDown,
  Size? iOSSurface,
}) => SweepScenario(
  kind: SweepKind.overlay,
  name: id,
  route: AppRoutes.overview,
  setUp: (tester, _) => pumpSweepApp(tester),
  navigate: (tester, l10n) async {
    show(_page(tester), tester);
    if (after != null) {
      await tester.pumpAndSettle();
      await after(tester, l10n);
    }
  },
  expectScreen: expectScreen,
  tearDown: tearDown,
  iOSSurface: iOSSurface,
);

Task _task(int id) => sweepData().tasks.all.firstWhere((task) => task.id == id);

Finder _platformFinder(Finder android, Finder iOS) =>
    defaultTargetPlatform == TargetPlatform.iOS ? iOS : android;

/// The sheets, pickers, dialogs, menus and snackbars the app shows over
/// its pages, on both platforms where they differ.
final List<SweepScenario> overlayScenarios = [
  _overlay(
    'detail sheet',
    show: (context, _) => unawaited(showTaskDetail(context, task: _task(1))),
    expectScreen: (_) => find.byType(TaskDetailSheet),
  ),
  _overlay(
    'new-task sheet',
    show: (context, _) =>
        unawaited(showNewTaskSheet(context, projectId: workProjectId)),
    expectScreen: (_) => find.byType(NewTaskSheet),
  ),
  _overlay(
    'new-task sheet, more options',
    show: (context, _) =>
        unawaited(showNewTaskSheet(context, projectId: workProjectId)),
    after: (tester, l10n) async {
      await tester.enterText(find.byType(TextField).first, 'Plan ');
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.newTaskMoreOptions));
    },
    expectScreen: (l10n) => find.text(l10n.newTaskFewerOptions),
  ),
  _overlay(
    'account switcher',
    show: (context, _) => unawaited(showAccountSwitcher(context)),
    expectScreen: (_) => find.byType(AccountSwitcherSheet),
  ),
  _overlay(
    'date-time picker',
    show: (context, _) => unawaited(
      pickDateTime(
        context,
        current: sweepNow.add(const Duration(days: 1)),
        now: sweepNow,
        display: const DisplaySettings(),
      ),
    ),
    expectScreen: (_) => _platformFinder(
      find.byType(DatePickerDialog),
      find.byType(CupertinoDatePicker),
    ),
    // The wheel sizes its columns to the widest text; the test font's
    // square glyphs need 524 px for the German date column, where the
    // system font needs about half. Real widths are the manual pass's.
    iOSSurface: const Size(540, 740),
  ),
  _overlay(
    'time picker',
    show: (context, _) => unawaited(
      pickTimeOfDay(
        context,
        initial: const TimeOfDay(hour: 9, minute: 30),
        display: const DisplaySettings(),
      ),
    ),
    expectScreen: (_) => _platformFinder(
      find.byType(TimePickerDialog),
      find.byType(CupertinoDatePicker),
    ),
  ),
  _overlay(
    'day-range picker',
    show: (context, _) => unawaited(
      pickDayRange(
        context,
        first: sweepNow,
        last: sweepNow.add(const Duration(days: 6)),
        now: sweepNow,
        firstDayOfWeekIndex: 1,
      ),
    ),
    expectScreen: (_) => _platformFinder(
      find.byType(DatePickerDialog),
      _byTypeName('_CupertinoDayRangeSheet'),
    ),
  ),
  _overlay(
    'project picker',
    show: (context, _) => unawaited(
      pickProject(
        context,
        projects: sweepData().projects.all,
        selectedId: workProjectId,
      ),
    ),
    expectScreen: (_) => _byTypeName('_ProjectList'),
  ),
  _overlay(
    'label picker',
    show: (context, _) => unawaited(pickLabels(context, selected: [errands])),
    expectScreen: (_) => find.byType(LabelPicker),
  ),
  _overlay(
    'reminders sheet',
    show: (context, tester) => unawaited(
      editReminders(
        context,
        repository: containerOf(tester).read(taskRepositoryProvider)!,
        taskId: 2,
      ),
    ),
    expectScreen: (_) => find.byType(TaskRemindersSheet),
  ),
  _overlay(
    'assignee picker',
    show: (context, _) => unawaited(
      pickAssignees(context, projectId: workProjectId, selected: const [kim]),
    ),
    expectScreen: (_) => find.byType(AssigneePicker),
  ),
  _overlay(
    'default-project picker',
    show: (context, _) => unawaited(
      pickDefaultProject(
        context,
        projects: sweepData().projects.all,
        selectedId: workProjectId,
      ),
    ),
    expectScreen: (_) => _byTypeName('_DefaultProjectList'),
  ),
  _overlay(
    'option sheet',
    show: (context, _) {
      final l10n = context.l10n;
      unawaited(
        showOptionSheet<int>(
          context,
          title: l10n.taskDetailPriority,
          options: [
            for (final priority in TaskPriority.values)
              SheetOption(
                value: priority.value,
                label: priority.name,
                selected: priority == TaskPriority.high,
                subtitle: priority == TaskPriority.doNow
                    ? l10n.boardDoneColumnHint
                    : null,
              ),
          ],
        ),
      );
    },
    expectScreen: (_) => _byTypeName('_OptionList<int>'),
  ),
  _overlay(
    'delete-task dialog',
    show: (context, _) =>
        unawaited(confirmDeleteTask(context, title: 'Call the plumber')),
    expectScreen: (_) => alertDialog,
  ),
  _overlay(
    'sign-out dialog',
    show: (context, tester) => unawaited(
      confirmRemoveAccount(
        context,
        entry: containerOf(tester).read(accountsProvider).value!.activeAccount!,
        pendingChanges: 2,
      ),
    ),
    expectScreen: (_) => alertDialog,
  ),
  _overlay(
    'done snackbar',
    show: (context, _) =>
        unawaited(showMarkedDoneSnackBar(context, onUndo: () {})),
    expectScreen: (_) => find.byType(SnackBar),
    tearDown: (tester, _) async {
      ScaffoldMessenger.of(_page(tester)).removeCurrentSnackBar();
      await tester.pumpAndSettle();
    },
  ),
  _overlay(
    'bin snackbar',
    show: (context, _) {
      final l10n = context.l10n;
      showDeletedSnackBar(
        ScaffoldMessenger.of(context),
        text: l10n.taskMovedToTrash,
        undoLabel: l10n.undo,
        persist: MediaQuery.accessibleNavigationOf(context),
        onUndo: () {},
      );
    },
    expectScreen: (_) => find.byType(SnackBar),
    tearDown: (tester, _) async {
      ScaffoldMessenger.of(_page(tester)).removeCurrentSnackBar();
      await tester.pumpAndSettle();
    },
  ),
  _overlay(
    'one-time secret page',
    show: (context, _) {
      final l10n = context.l10n;
      unawaited(
        _pushPage(
          context,
          OneTimeSecretPage(
            pageTitle: l10n.caldavNewToken,
            secret: 'dummy-caldav-secret-0123456789',
            title: l10n.oneTimeSecretCaldavTitle,
            usage: l10n.oneTimeSecretCaldavUsage('alice'),
          ),
        ),
      );
    },
    expectScreen: (_) => find.byType(OneTimeSecretPage),
  ),
  SweepScenario(
    kind: SweepKind.overlay,
    name: 'avatar crop page',
    route: AppRoutes.overview,
    setUp: (tester, _) => pumpSweepApp(tester),
    navigate: (tester, _) async {
      unawaited(
        _pushPage(
          _page(tester),
          AvatarCropPage(source: wideTestPng, onUpload: (_) async {}),
        ),
      );
      // The page decodes the photo with the engine, outside the test's
      // fake time; a progress indicator spins meanwhile.
      for (var i = 0; i < 50; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(InteractiveViewer).evaluate().isNotEmpty) break;
      }
    },
    expectScreen: (_) => find.byType(InteractiveViewer),
  ),
  SweepScenario(
    kind: SweepKind.overlay,
    name: 'image viewer',
    route: AppRoutes.overview,
    setUp: (tester, _) async {
      final data = sweepData();
      data.attachmentImages.images[(1, 3, null)] = samplePngImage;
      await pumpSweepApp(tester, data: data);
    },
    navigate: (tester, _) async => unawaited(
      showAttachmentImage(
        _page(tester),
        taskId: 1,
        attachmentId: 3,
        description: 'The fence',
      ),
    ),
    expectScreen: (_) => find.byType(AttachmentImageViewer),
  ),
];

/// A page as the app pushes one over everything: full screen, on the root
/// navigator.
Future<void> _pushPage(BuildContext context, Widget page) => Navigator.of(
  context,
  rootNavigator: true,
).push<void>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => page));

/// A link-share guest's task sheet.
final List<SweepScenario> guestOverlayScenarios = [
  SweepScenario(
    kind: SweepKind.state,
    name: 'guest detail sheet',
    route: AppRoutes.overview,
    setUp: (tester, _) async {
      final data = SyncFakes(now: sweepNow);
      data.tasks.all = [_task(1).copyWith(projectId: guestProjectId)];
      await pumpGuestApp(
        tester,
        auth: AuthFakes(),
        data: data,
        permission: Permission.write,
      );
    },
    navigate: (tester, _) async => unawaited(
      showTaskDetail(
        _page(tester),
        task: _task(1).copyWith(projectId: guestProjectId),
      ),
    ),
    expectScreen: (_) => find.byType(TaskDetailSheet),
  ),
];
