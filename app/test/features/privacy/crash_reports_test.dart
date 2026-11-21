import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_consent.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';
import 'package:vikunja_mobile/features/about/application/support_details.dart';
import 'package:vikunja_mobile/features/about/presentation/support_details_page.dart';
import 'package:vikunja_mobile/features/home/presentation/home_shell.dart';
import 'package:vikunja_mobile/features/privacy/presentation/privacy_page.dart';
import 'package:vikunja_mobile/features/privacy/presentation/privacy_section.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/crash_report_fakes.dart';
import '../../helpers/guest_app.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  late AuthFakes auth;
  late FakeCrashReportSdk sdk;

  setUp(() {
    auth = AuthFakes();
    sdk = FakeCrashReportSdk();
  });

  String? stored() => auth.preferences.values[CrashReportConsentStore.key];

  Finder question() => find.text(en.crashReportsQuestionTitle);

  Future<void> pumpShell(
    WidgetTester tester, {
    List<Override>? overrides,
    bool seed = true,
  }) async {
    final crashReports = overrides ?? crashReportOverrides(sdk: sdk);
    if (seed) {
      await pumpSignedInApp(tester, auth: auth, overrides: crashReports);
    } else {
      await pumpVikunjaApp(tester, auth: auth, overrides: crashReports);
    }
  }

  group('the one question', () {
    testWidgets('comes when the first account reaches the shell, with Allow '
        'and No thanks and neither preselected; Allow allows', (tester) async {
      await pumpShell(tester);

      expect(question(), findsOneWidget);
      expect(find.text(en.crashReportsQuestionBody), findsOneWidget);
      expect(find.text(en.crashReportsQuestionAllow), findsOneWidget);
      expect(find.text(en.crashReportsQuestionDecline), findsOneWidget);
      expect(stored(), isNull);

      await tester.tap(find.text(en.crashReportsQuestionAllow));
      await tester.pumpAndSettle();

      expect(question(), findsNothing);
      expect(stored(), 'allowed');
    });

    testWidgets('No thanks declines, and the question never comes again', (
      tester,
    ) async {
      await pumpShell(tester);
      await tester.tap(find.text(en.crashReportsQuestionDecline));
      await tester.pumpAndSettle();
      expect(stored(), 'declined');

      await tester.pumpWidget(const SizedBox());
      await pumpShell(tester, seed: false);
      expect(find.byType(HomeShell), findsOneWidget);
      expect(question(), findsNothing);
      expect(stored(), 'declined');
    });

    testWidgets('closed by the app, as a notification or widget tap closes '
        'every dialog, it is not answered and comes again at the next start', (
      tester,
    ) async {
      await pumpShell(tester);
      expect(question(), findsOneWidget);

      containerOf(tester).read(rootModalRoutesProvider).closeAll();
      await tester.pumpAndSettle();

      expect(question(), findsNothing);
      expect(stored(), isNull);
      expect(
        await containerOf(tester)
            .read(crashReportConsentControllerProvider.future),
        CrashReportConsent.notAsked,
      );

      // A new start: a new container and a new shell.
      await tester.pumpWidget(const SizedBox());
      await pumpShell(tester, seed: false);
      expect(question(), findsOneWidget);
    });

    testWidgets('going back declines; a tap beside it does not answer', (
      tester,
    ) async {
      await pumpShell(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(question(), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(question(), findsNothing);
      expect(stored(), 'declined');
    });

    testWidgets('an answer already given is not asked again', (tester) async {
      auth.preferences.values[CrashReportConsentStore.key] = 'allowed';
      await pumpShell(tester);

      expect(question(), findsNothing);
      expect(stored(), 'allowed');
    });

    testWidgets('a build without a DSN never asks', (tester) async {
      await pumpShell(tester, overrides: crashReportOverrides(dsn: null));

      expect(question(), findsNothing);
      expect(stored(), isNull);
    });

    testWidgets('a link-share guest is asked too', (tester) async {
      await pumpGuestApp(
        tester,
        auth: auth,
        data: SyncFakes(),
        overrides: crashReportOverrides(sdk: sdk),
      );

      expect(question(), findsOneWidget);
    });
  });

  group("the Account tab's entry and the support details", () {
    Future<void> pumpSection(
      WidgetTester tester, {
      String? dsn = testCrashReportsDsn,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...crashReportOverrides(dsn: dsn, sdk: sdk),
            preferencesStoreProvider.overrideWithValue(auth.preferences),
            privacySettingsProvider.overrideWith(
              (ref) async => const PrivacySettings(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: appSupportedLocales,
            home: Scaffold(body: PrivacySection()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the privacy entry says whether crash reports are on, only '
        'in a build with them', (tester) async {
      await pumpSection(tester, dsn: null);
      expect(find.text(en.privacyEntryAppLockOff), findsOneWidget);

      await pumpSection(tester);
      expect(
        find.text(
          en.privacyEntryWithCrashReports(en.privacyEntryAppLockOff, 'off'),
        ),
        findsOneWidget,
      );
      expect(find.text('App lock: Off · Crash reports: Off'), findsOneWidget);

      auth.preferences.values[CrashReportConsentStore.key] = 'allowed';
      await tester.pumpWidget(const SizedBox());
      await pumpSection(tester);
      expect(find.text('App lock: Off · Crash reports: On'), findsOneWidget);
    });

    testWidgets("the support details' note says that the log leaves with "
        'crash reports, only in a build with them', (tester) async {
      Future<void> pumpDetails({String? dsn}) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...crashReportOverrides(dsn: dsn, sdk: sdk),
              supportSnapshotProvider.overrideWith(
                (ref) => Completer<SupportSnapshot>().future,
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: appSupportedLocales,
              home: SupportDetailsPage(),
            ),
          ),
        );
        await tester.pump();
      }

      await pumpDetails();
      expect(find.text(en.supportDetailsLogNote), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await pumpDetails(dsn: testCrashReportsDsn);
      expect(find.text(en.supportDetailsLogNoteCrashReports), findsOneWidget);
      expect(find.text(en.supportDetailsLogNote), findsNothing);
    });
  });

  group('the privacy page', () {
    Finder crashSwitch() =>
        find.widgetWithText(SwitchListTile, en.privacyCrashReportsSwitch);

    Future<void> openPrivacy(WidgetTester tester) async {
      unawaited(
        containerOf(tester).read(appRouterProvider).push(AppRoutes.privacy),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(en.privacyCrashReportsNote),
        150,
        scrollable: find
            .descendant(
              of: find.byType(PrivacyPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('has no crash reports in a build without a DSN', (
      tester,
    ) async {
      await pumpShell(tester, overrides: crashReportOverrides(dsn: null));
      unawaited(
        containerOf(tester).read(appRouterProvider).push(AppRoutes.privacy),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PrivacyPage), findsOneWidget);
      expect(find.text(en.privacyCrashReportsHeading), findsNothing);
    });

    testWidgets('the switch takes effect at once: on starts the SDK, off '
        'closes it and deletes the unsent reports', (tester) async {
      auth.preferences.values[CrashReportConsentStore.key] = 'declined';
      await pumpShell(tester);
      // What bootstrap does for the app's lifetime.
      final reporter = containerOf(tester)
          .listen(crashReporterProvider, (_, _) {});
      addTearDown(reporter.close);
      await tester.pumpAndSettle();
      expect(sdk.calls, ['deleteUnsent']);
      await openPrivacy(tester);

      expect(find.text(en.privacyCrashReportsHeading), findsOneWidget);
      expect(tester.widget<SwitchListTile>(crashSwitch()).value, isFalse);

      await tester.tap(crashSwitch());
      await tester.pumpAndSettle();
      expect(stored(), 'allowed');
      expect(sdk.calls, ['deleteUnsent', 'start']);
      expect(tester.widget<SwitchListTile>(crashSwitch()).value, isTrue);

      await tester.tap(crashSwitch());
      await tester.pumpAndSettle();
      expect(stored(), 'declined');
      expect(sdk.calls, ['deleteUnsent', 'start', 'stop', 'deleteUnsent']);
    });
  });
}
