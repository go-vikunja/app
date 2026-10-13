import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/background/background_run_log.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final start = DateTime.utc(2026, 10, 13, 12);
  late AuthFakes auth;
  late DateTime now;

  setUp(() {
    auth = AuthFakes();
    now = start;
  });

  Future<String> pumpAccountTab(
    WidgetTester tester, {
    String? lastRun,
    AppLocalizations? l10n,
  }) async {
    final entry = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    if (lastRun != null) {
      await auth.preferences.setString(
        BackgroundRunLog.lastRunAtKey(entry.id),
        lastRun,
      );
    }
    await pumpVikunjaApp(
      tester,
      auth: auth,
      sync: SyncFakes(now: start),
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    await openTab(tester, (l10n ?? en).tabAccount);
    return entry.id;
  }

  testWidgets('says when the background sync has not run yet', (tester) async {
    await pumpAccountTab(tester);

    expect(find.text(en.accountBackgroundSyncNever), findsOneWidget);
    expect(find.text(en.accountBackgroundSyncIosHint), findsNothing);
  });

  testWidgets('on iOS adds that the system decides when it runs', (
    tester,
  ) async {
    await pumpAccountTab(tester);

    expect(find.text(en.accountBackgroundSyncNever), findsOneWidget);
    expect(find.text(en.accountBackgroundSyncIosHint), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('shows how long ago it last ran, without the hint', (
    tester,
  ) async {
    await pumpAccountTab(
      tester,
      lastRun: start.subtract(const Duration(hours: 2)).toIso8601String(),
    );

    expect(
      find.text(en.accountBackgroundSync(en.relativeHoursAgo(2))),
      findsOneWidget,
    );
    expect(find.text(en.accountBackgroundSyncNever), findsNothing);
    expect(find.text(en.accountBackgroundSyncIosHint), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('reads the runner’s note again while the app is in front', (
    tester,
  ) async {
    final accountId = await pumpAccountTab(tester);
    expect(find.text(en.accountBackgroundSyncNever), findsOneWidget);

    await auth.preferences.setString(
      BackgroundRunLog.lastRunAtKey(accountId),
      start.toIso8601String(),
    );
    now = start.add(const Duration(seconds: 20));
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();

    expect(find.text(en.accountBackgroundSyncJustNow), findsOneWidget);
  });

  testWidgets('in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await pumpAccountTab(
      tester,
      lastRun: start.subtract(const Duration(minutes: 5)).toIso8601String(),
      l10n: de,
    );

    expect(
      find.text(de.accountBackgroundSync(de.relativeMinutesAgo(5))),
      findsOneWidget,
    );
  });
}
