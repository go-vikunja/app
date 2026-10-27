import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_page.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_tile.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/sync/presentation/first_sync_screen.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/connection_fakes.dart';
import '../../helpers/guest_app.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/tls_fixtures.dart';

void main() {
  // fullServer270's address.
  final origin = OriginKey.of(Uri.parse('https://tasks.example.org/vikunja'));
  late AuthFakes auth;

  setUp(() => auth = AuthFakes());

  Finder tabList() => find
      .descendant(
        of: find.byType(AccountTab),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> showConnectionTile(WidgetTester tester) async {
    await openTab(tester, en.tabAccount);
    await tester.scrollUntilVisible(
      find.byType(ConnectionTile),
      100,
      scrollable: tabList(),
    );
    await tester.pumpAndSettle();
  }

  String? subtitle(WidgetTester tester) {
    final tile = tester.widget<ListTile>(
      find.descendant(
        of: find.byType(ConnectionTile),
        matching: find.byType(ListTile),
      ),
    );
    return (tile.subtitle as Text?)?.data;
  }

  group("the Account tab's Connection entry", () {
    testWidgets('says what is stored, then what needs the user, and opens '
        'the screen', (tester) async {
      await pumpSignedInApp(tester, auth: auth);
      await showConnectionTile(tester);
      expect(find.text(en.connectionTitle), findsOneWidget);
      expect(subtitle(tester), isNull);

      final profiles = profilesOver(auth);
      await profiles.trustCertificate(
        origin,
        tlsFixtureCertificate('selfsigned.pem'),
      );
      await tester.pumpAndSettle();
      expect(subtitle(tester), en.connectionSummaryPinned);

      await profiles.recordPinMismatch(origin, renewedCertificate);
      await tester.pumpAndSettle();
      expect(subtitle(tester), en.connectionStatusPinMismatch);

      await tester.tap(find.text(en.connectionTitle));
      await tester.pumpAndSettle();
      expect(find.byType(ConnectionPage), findsOneWidget);
      expect(find.text(en.connectionMismatchTitle), findsOneWidget);
    });

    testWidgets('is there for a guest too', (tester) async {
      await pumpGuestApp(tester, auth: auth, data: SyncFakes());
      await showConnectionTile(tester);

      await tester.tap(find.text(en.connectionTitle));
      await tester.pumpAndSettle();
      expect(find.byType(ConnectionPage), findsOneWidget);
      expect(find.text(en.connectionOptionsFor('$origin')), findsOneWidget);
    });
  });

  group('a sync failure the settings fix', () {
    testWidgets('offers them in the sync status, and is no outage', (
      tester,
    ) async {
      final now = DateTime.now().toUtc();
      final data = SyncFakes(
        now: now,
        status: SyncFailed(
          failure: const NetworkFailure(NetworkProblem.profileIncomplete),
          lastSyncedAt: now,
        ),
      );
      data.engine.onRefresh = () async =>
          throw const NetworkFailure(NetworkProblem.profileIncomplete);
      await pumpSignedInApp(tester, auth: auth, sync: data);
      await openTab(tester, en.tabAccount);
      final settings = find.text(en.connectionOpenSettings);
      await tester.scrollUntilVisible(settings, 100, scrollable: tabList());
      await tester.pumpAndSettle();

      expect(
        find.text(
          en.connectionProfileIncompleteExplanation('tasks.example.org'),
        ),
        findsOneWidget,
      );
      expect(find.text(en.offlineNotice), findsNothing);
      await tester.tap(settings);
      await tester.pumpAndSettle();
      expect(find.byType(ConnectionPage), findsOneWidget);
    });

    testWidgets('of unreadable settings offers their reset on the first '
        'sync', (tester) async {
      final data = SyncFakes(
        status: const SyncFailed(
          failure: NetworkFailure(NetworkProblem.profileDamaged),
          lastSyncedAt: null,
        ),
      );
      data.engine.onEnsureInitialSync = () async =>
          throw const NetworkFailure(NetworkProblem.profileDamaged);
      usePhoneSurface(tester, logicalSize: const Size(400, 1400));
      await pumpSignedInApp(tester, auth: auth, sync: data, settle: false);
      await pumpUntil(tester, find.byType(FirstSyncScreen));
      await pumpUntil(tester, find.text(en.connectionReset));

      expect(find.text(en.connectionOpenSettings), findsNothing);
      await tester.tap(find.text(en.connectionReset));
      await pumpFrames(tester, 5);
      expect(find.text(en.connectionResetTitle), findsOneWidget);
    });
  });
}
