import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/data_export_page.dart';
import 'package:vikunja_mobile/features/common/presentation/file_size_text.dart';

import '../../helpers/account_settings_fakes.dart';
import '../../helpers/pump_app.dart';
import 'security_harness.dart';

void main() {
  late SecurityHarness harness;

  setUp(() => harness = SecurityHarness());

  UserDataExport readyExport() => UserDataExport(
    id: 458,
    size: 2372,
    created: harness.now.subtract(const Duration(hours: 2)),
    expires: harness.now.add(const Duration(days: 7)),
  );

  Future<void> pumpPage(WidgetTester tester, {bool isLocalUser = true}) =>
      harness.pump(
        tester,
        location: AppRoutes.accountDataExport,
        state: fakeAccountSettingsState(isLocalUser: isLocalUser),
      );

  testWidgets('without an export: what it holds and the way to request one', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text(en.dataExportIntro), findsOneWidget);
    expect(find.text(en.dataExportNoneTitle), findsOneWidget);
    expect(find.text(en.dataExportDownload), findsNothing);
    expect(
      find.text(
        '${en.dataExportRequestNote} ${en.accountSettingsWebAsksPassword}',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text(en.dataExportRequest));
    await tester.pumpAndSettle();
    expect(harness.links.opened, [webPage('user/settings/data-export')]);
  });

  testWidgets('a ready export shows its size and end, and downloads on the '
      'web', (tester) async {
    harness.security.export = readyExport();
    await pumpPage(tester);

    expect(find.text(en.dataExportReadyTitle), findsOneWidget);
    expect(find.textContaining(formatFileSize(en, 2372)), findsOneWidget);
    await tester.tap(find.text(en.dataExportDownload));
    await tester.pumpAndSettle();

    expect(harness.links.opened, [webPage('user/export/download')]);
  });

  testWidgets('back from the browser, the export is read again', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.text(en.dataExportRequest));
    await tester.pumpAndSettle();

    harness.security.export = readyExport();
    resumeApp(tester);
    await tester.pumpAndSettle();

    expect(find.text(en.dataExportReadyTitle), findsOneWidget);
  });

  testWidgets('an expired export counts as none', (tester) async {
    harness.security.export = UserDataExport(
      id: 1,
      size: 10,
      expires: harness.now.subtract(const Duration(minutes: 1)),
    );
    await pumpPage(tester);

    expect(find.text(en.dataExportNoneTitle), findsOneWidget);
  });

  testWidgets('a sign-in provider account is not told about a password', (
    tester,
  ) async {
    await pumpPage(tester, isLocalUser: false);

    expect(find.text(en.dataExportRequestNote), findsOneWidget);
  });

  testWidgets('a status that cannot be read offers a retry; the request '
      'still opens the web', (tester) async {
    harness.security.failures['dataExport'] = const NetworkFailure(
      NetworkProblem.unreachable,
    );
    await pumpPage(tester);

    expect(find.text(en.dataFailureLoadTitle), findsOneWidget);
    await scrollToIn(tester, DataExportPage, find.text(en.dataExportRequest));
    await tester.tap(find.text(en.dataExportRequest));
    await tester.pumpAndSettle();
    expect(harness.links.opened, hasLength(1));

    harness.security.failures.clear();
    await tester.tap(find.text(en.retry));
    await tester.pumpAndSettle();
    expect(find.text(en.dataExportNoneTitle), findsOneWidget);
  });

  testWidgets('is in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await pumpPage(tester);

    expect(find.text(de.dataExportTitle), findsOneWidget);
    expect(find.text(de.dataExportRequest), findsOneWidget);
  });
}
