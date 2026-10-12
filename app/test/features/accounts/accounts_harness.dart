import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_switcher_button.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_switcher_sheet.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fakes.dart';
import '../../helpers/label_user_fakes.dart';
import '../../helpers/notification_ui_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

/// Alice on the 2.7 server (active), Bob on a 2.3 server and Carol on a
/// server with a port, each with their own data. Carol was active more
/// recently than Bob.
final class ThreeAccounts {
  final auth = AuthFakes();
  final now = DateTime.now();
  late final data = SyncFakes(now: now);
  late final RegisteredAccount alice;
  late final RegisteredAccount bob;
  late final RegisteredAccount carol;

  AccountDataFakes get aliceData => data.shared;
  AccountDataFakes get bobData => data.accounts[bob.id]!;
  AccountDataFakes get carolData => data.accounts[carol.id]!;

  Future<void> seed({
    bool bobNeedsReauth = false,
    SyncStatus? bobStatus,
    bool withCarol = true,
    String aliceName = 'Alice Example',
    String bobName = 'Bob',
  }) async {
    alice = await seedUser(
      auth,
      fullServer270(),
      userId: 7,
      username: 'alice',
      displayName: aliceName,
    );
    bob = await seedUser(
      auth,
      oauthServer230(),
      userId: 8,
      username: 'bob',
      displayName: bobName,
      needsReauth: bobNeedsReauth,
    );
    data.accounts[bob.id] = AccountDataFakes(now: now, status: bobStatus);
    if (withCarol) {
      carol = await seedUser(
        auth,
        oauthServer230(root: 'https://tasks.example.net:8443'),
        userId: 9,
        username: 'carol',
        displayName: 'Carol',
      );
      data.accounts[carol.id] = AccountDataFakes(now: now);
      await auth.registry.setActive(carol.id);
    }
    await auth.registry.setActive(alice.id);
  }

  Future<void> pump(
    WidgetTester tester, {
    FakeServerConnector? connector,
    NotificationFakes? notifications,
    List<Override> overrides = const [],
    bool settle = true,
  }) => pumpVikunjaApp(
    tester,
    auth: auth,
    sync: data,
    connector: connector,
    notifications: notifications,
    settle: settle,
    overrides: [
      clockProvider.overrideWithValue(() => now),
      // The edit page's sections would open a database otherwise.
      labelRepositoryProvider.overrideWithValue(FakeLabelRepository()),
      userRepositoryProvider.overrideWithValue(FakeUserRepository()),
      ...overrides,
    ],
  );
}

/// Not active unless it is the first account.
Future<RegisteredAccount> seedUser(
  AuthFakes auth,
  ServerConnection server, {
  required int userId,
  required String username,
  required String displayName,
  bool needsReauth = false,
}) => auth.seedAccount(
  server,
  tokens: issueTokens(
    issuedAt: DateTime.now().toUtc(),
    userId: userId,
    username: username,
  ),
  displayName: displayName,
  needsReauth: needsReauth,
  activate: false,
);

Finder get switcherSheet => find.byType(AccountSwitcherSheet);

Future<void> openSwitcher(WidgetTester tester) async {
  await tester.tap(find.byType(AccountSwitcherButton));
  await tester.pumpAndSettle();
}

Finder inSheet(Finder finder) =>
    find.descendant(of: switcherSheet, matching: finder);
