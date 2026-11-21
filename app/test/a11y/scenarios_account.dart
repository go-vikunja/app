import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_consent.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/security/device_authenticator.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';
import 'package:vikunja_mobile/features/about/presentation/about_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/api_token_form_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/api_tokens_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/avatar_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/caldav_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/data_export_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/sessions_page.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/privacy/presentation/privacy_page.dart';

import '../helpers/account_security_fakes.dart';
import '../helpers/app_lock_fakes.dart';
import '../helpers/auth_fakes.dart';
import '../helpers/crash_report_fakes.dart';
import '../helpers/sync_fakes.dart';
import 'sweep_data.dart';
import 'sweep_harness.dart';

SweepScenario _settingsPage(
  String route,
  Type page, {
  void Function(SyncFakes data)? seed,
  Object? extra,
}) => SweepScenario.route(
  route,
  setUp: (tester, _) async {
    final data = sweepData();
    seed?.call(data);
    await pumpSweepApp(tester, data: data);
  },
  navigate: (tester, _) async => pushTo(tester, route, extra: extra),
  expectScreen: (_) => find.byType(page),
);

void _seedApiTokens(SyncFakes data) => data.accountSecurity.apiTokenList = [
  fakeApiToken(
    title: 'Home automation',
    expiresAt: sweepNow.add(const Duration(days: 12)),
    permissions: const {
      'projects_views_tasks': ['read_all'],
      'tasks_attachments': ['create', 'read_all'],
    },
  ),
  fakeApiToken(
    id: 2,
    title: 'Backup script',
    expiresAt: sweepNow.subtract(const Duration(days: 40)),
  ),
];

/// The device lock behind the privacy page and the lock screen; answers
/// with [result].
Future<void> _pumpWithLock(
  WidgetTester tester, {
  bool lockOn = false,
  bool crashReports = false,
  DeviceAuthResult result = DeviceAuthResult.success,
}) async {
  final auth = AuthFakes();
  if (lockOn) {
    await storePrivacySettings(
      auth.preferences,
      const PrivacySettings(appLock: true),
    );
  }
  if (crashReports) {
    await auth.preferences.setString(CrashReportConsentStore.key, 'allowed');
  }
  useResumedLifecycle(tester);
  await pumpSweepApp(
    tester,
    auth: auth,
    overrides: [
      deviceAuthenticatorProvider.overrideWithValue(
        FakeDeviceAuthenticator(result: result),
      ),
      if (crashReports) ...crashReportOverrides(),
    ],
  );
  await pumpPastPromptSettle(tester);
}

/// The account's settings on the server, the device's privacy and the
/// About page, from the Account tab.
final List<SweepScenario> accountRouteScenarios = [
  _settingsPage(AppRoutes.accountSettings, AccountSettingsPage),
  _settingsPage(AppRoutes.accountAvatar, AvatarPage),
  _settingsPage(AppRoutes.accountSessions, SessionsPage),
  _settingsPage(
    AppRoutes.accountApiTokens,
    ApiTokensPage,
    seed: _seedApiTokens,
  ),
  _settingsPage(AppRoutes.accountApiTokenNew, ApiTokenFormPage),
  _settingsPage(
    AppRoutes.accountCaldav,
    CaldavPage,
    seed: (data) => data.accountSecurity
      ..totp = TotpStatus.enabled
      ..caldavTokenList = [
        for (var id = 1; id <= 3; id++)
          CaldavToken(
            id: id,
            created: sweepNow.subtract(Duration(days: id)),
          ),
      ],
  ),
  _settingsPage(
    AppRoutes.accountDataExport,
    DataExportPage,
    seed: (data) => data.accountSecurity.export = UserDataExport(
      id: 3,
      size: 123456789,
      expires: sweepNow.add(const Duration(days: 6)),
    ),
  ),
  SweepScenario.route(
    AppRoutes.privacy,
    setUp: (tester, _) =>
        _pumpWithLock(tester, lockOn: true, crashReports: true),
    navigate: (tester, _) async => pushTo(tester, AppRoutes.privacy),
    expectScreen: (_) => find.byType(PrivacyPage),
  ),
  SweepScenario.route(
    AppRoutes.about,
    setUp: (tester, _) => pumpSweepApp(tester),
    navigate: (tester, _) async => pushTo(tester, AppRoutes.about),
    expectScreen: (_) => find.byType(AboutPage),
  ),
];

SweepScenario _sessions(
  String state,
  void Function(FakeAccountSecurityRepository security) seed,
  ScreenFinder expect, {
  bool settle = true,
}) => SweepScenario(
  kind: SweepKind.state,
  name: '${AppRoutes.accountSessions} $state',
  route: AppRoutes.accountSessions,
  settle: settle,
  setUp: (tester, _) async {
    final data = sweepData();
    seed(data.accountSecurity);
    await pumpSweepApp(tester, data: data);
  },
  navigate: (tester, _) async => pushTo(tester, AppRoutes.accountSessions),
  expectScreen: expect,
);

/// The sessions list, a list the page reads from the server, in each of
/// its states; and the lock screen with each message, which the app lock
/// draws over every route.
final List<SweepScenario> accountStateScenarios = [
  SweepScenario(
    kind: SweepKind.state,
    name: '${AppRoutes.account} background sync limited',
    route: AppRoutes.account,
    setUp: (tester, _) =>
        pumpSweepApp(tester, overrides: [limitedBackgroundSync]),
    navigate: (tester, l10n) async {
      goTo(tester, AppRoutes.account);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(l10n.backgroundSyncLimitedTitle),
        300,
        scrollable: find
            .descendant(
              of: find.byType(AccountTab),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    },
    expectScreen: (l10n) => find.text(l10n.backgroundSyncLimitedTitle),
  ),
  SweepScenario(
    kind: SweepKind.state,
    name: '${AppRoutes.account} sync problems',
    route: AppRoutes.account,
    setUp: (tester, _) async {
      final data = sweepData();
      data.tasks
        ..pendingChanges = 3
        ..syncProblems = [
          for (final (id, failure) in const <(int, VikunjaFailure)>[
            (1, Forbidden(code: 7003)),
            (2, ServerFailure(502)),
            (3, DescriptionConflict()),
          ])
            SyncProblem(
              operationId: 'op-$id',
              kind: OutboxOperationKind.updateTask,
              taskId: id,
              taskTitle: 'Task $id',
              failure: failure,
              failedAt: sweepNow.subtract(Duration(minutes: id)),
            ),
        ];
      await pumpSweepApp(tester, data: data);
    },
    navigate: (tester, l10n) async {
      goTo(tester, AppRoutes.account);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(l10n.syncProblemsRetryAll),
        300,
        scrollable: find
            .descendant(
              of: find.byType(AccountTab),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    },
    expectScreen: (l10n) => find.text(l10n.syncProblemsRetryAll),
  ),
  _sessions(
    'empty',
    (security) => security
      ..sessionList = []
      ..currentSession = null,
    (_) => find.byType(SessionsPage),
  ),
  _sessions(
    'failure',
    (security) => security.failures['sessions'] = const ServerFailure(502),
    (_) => find.byType(DataFailureCard),
  ),
  _sessions(
    'offline',
    (security) => security.failures['sessions'] = const NetworkFailure(
      NetworkProblem.unreachable,
    ),
    (_) => find.byType(DataFailureCard),
  ),
  _sessions(
    'loading',
    (security) => security.beforeCall = (_) => Completer<void>().future,
    (_) => find.descendant(
      of: find.byType(SessionsPage),
      matching: find.byType(LoadingPlaceholder),
    ),
    settle: false,
  ),
  for (final (state, result) in [
    ('locked', DeviceAuthResult.cancelled),
    ('locked out', DeviceAuthResult.lockedOut),
    ('prompt stuck', DeviceAuthResult.inProgress),
    ('unavailable', DeviceAuthResult.unavailable),
  ])
    SweepScenario(
      kind: SweepKind.state,
      name: 'lock screen $state',
      route: AppRoutes.overview,
      setUp: (tester, _) => _pumpWithLock(tester, lockOn: true, result: result),
      expectScreen: (l10n) => find.text(l10n.appLockTitle),
    ),
  SweepScenario(
    kind: SweepKind.state,
    name: 'privacy cover',
    route: AppRoutes.overview,
    setUp: (tester, _) async {
      await _pumpWithLock(tester, lockOn: true);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    },
    expectScreen: (_) => find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_PrivacyCover',
    ),
    tearDown: (tester, _) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    },
  ),
];
