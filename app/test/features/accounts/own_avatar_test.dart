import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_mobile/core/avatar/avatar_cache.dart';
import 'package:vikunja_mobile/core/avatar/avatar_providers.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_switcher_button.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_tile.dart';
import 'package:vikunja_mobile/features/home/presentation/account_header.dart';

import '../../helpers/pump_app.dart';
import '../account_settings/avatar_fakes.dart';
import 'accounts_harness.dart';

void main() {
  late ThreeAccounts accounts;
  late Map<String, AvatarCache> caches;
  late List<(String, String, int)> requests;

  setUp(() {
    accounts = ThreeAccounts();
    caches = {};
    requests = [];
  });

  /// Every account's server answers a PNG for its own user, an SVG (the
  /// initials) for anyone else.
  AvatarCache cacheFor(String accountId) =>
      caches[accountId] ??= AvatarCache((username, size) async {
        requests.add((accountId, username, size));
        final own = {
          accounts.alice.id: 'alice',
          accounts.bob.id: 'bob',
          accounts.carol.id: 'carol',
        }[accountId];
        return username == own
            ? AvatarImage(bytes: wideTestPng, contentType: 'image/png')
            : AvatarImage(bytes: wideTestPng, contentType: 'image/svg+xml');
      });

  Future<void> pump(WidgetTester tester) async {
    usePhoneSurface(tester);
    await accounts.seed();
    await accounts.pump(
      tester,
      overrides: [
        accountAvatarCacheProvider.overrideWith(
          (ref, accountId) => cacheFor(accountId),
        ),
      ],
    );
  }

  Finder imageIn(Finder parent) =>
      find.descendant(of: parent, matching: find.byType(Image));

  testWidgets('the switcher button shows the own avatar', (tester) async {
    await pump(tester);

    expect(imageIn(find.byType(AccountSwitcherButton)), findsOneWidget);
    expect(requests, contains((accounts.alice.id, 'alice', 128)));
  });

  testWidgets("the switcher's tiles each ask their own server", (tester) async {
    await pump(tester);
    await openSwitcher(tester);

    for (final entry in [accounts.alice, accounts.bob, accounts.carol]) {
      final tile = find.byWidgetPredicate(
        (widget) => widget is AccountTile && widget.entry.id == entry.id,
      );
      expect(imageIn(tile), findsOneWidget, reason: entry.account.username);
    }
    expect(requests, contains((accounts.bob.id, 'bob', 128)));
    expect(requests, contains((accounts.carol.id, 'carol', 128)));
  });

  testWidgets('the Account tab header shows it and asks again once it '
      'changed, keeping the old picture meanwhile', (tester) async {
    await pump(tester);
    await openTab(tester, en.tabAccount);

    final header = find.byType(AccountHeader);
    expect(imageIn(header), findsOneWidget);
    final before = requests
        .where((request) => request.$1 == accounts.alice.id)
        .length;

    caches[accounts.alice.id]!.evict('alice');
    await tester.pump();
    expect(imageIn(header), findsOneWidget);
    await tester.pumpAndSettle();

    expect(
      requests.where((request) => request.$1 == accounts.alice.id).length,
      greaterThan(before),
    );
    expect(imageIn(header), findsOneWidget);
  });
}
