import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/features/accounts/presentation/accounts_section.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_controller.dart';

import '../../helpers/connection_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/tls_fixtures.dart';
import 'accounts_harness.dart';

void main() {
  late ThreeAccounts accounts;
  // Bob's server; Alice and Carol are on others.
  final bobOrigin = OriginKey.of(Uri.parse('https://vikunja.example.com'));

  setUp(() => accounts = ThreeAccounts());

  Future<void> trustBobsServer() =>
      profilesOver(accounts.auth)
          .trustCertificate(bobOrigin, tlsFixtureCertificate('selfsigned.pem'));

  Future<void> openRemoveDialog(WidgetTester tester, String name) async {
    await openTab(tester, en.tabAccount);
    final more = find.descendant(
      of: find.byType(AccountsSection),
      matching: find.byTooltip(en.accountMoreActions(name)),
    );
    await tester.scrollUntilVisible(
      more,
      100,
      scrollable: find
          .descendant(
            of: find.byType(AccountTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.accountRemove));
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.text(en.removeAccountDialogConfirm));
    await tester.pumpAndSettle();
  }

  testWidgets('removing the last account on a server with settings offers '
      'to forget them, checked, and forgets them after the sign-out', (
    tester,
  ) async {
    await accounts.seed();
    await trustBobsServer();
    await accounts.pump(tester);
    await openRemoveDialog(tester, 'Bob');

    expect(find.text(en.connectionForgetCheckbox), findsOneWidget);
    expect(find.text(en.connectionSummaryPinned), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    await confirm(tester);

    final registry = await accounts.auth.registry.load();
    expect(registry.find(accounts.bob.id), isNull);
    expect(await profilesOver(accounts.auth).metadataFor(bobOrigin), isNull);
  });

  testWidgets('a registry read that fails before the sign-out does not '
      'block it; the settings stay', (tester) async {
    await accounts.seed();
    await trustBobsServer();
    await accounts.pump(tester);

    accounts.auth.preferences.failNextRead.add(AccountRegistry.storageKey);
    await containerOf(tester)
        .read(signOutControllerProvider.notifier)
        .signOut(accounts.bob.id, forgetConnectionSettings: true);
    await tester.pumpAndSettle();

    expect(accounts.auth.preferences.failNextRead, isEmpty);
    final registry = await accounts.auth.registry.load();
    expect(registry.find(accounts.bob.id), isNull);
    expect(
      (await profilesOver(accounts.auth).metadataFor(bobOrigin))?.pin,
      isNotNull,
    );
  });

  testWidgets('unchecked, the settings stay', (tester) async {
    await accounts.seed();
    await trustBobsServer();
    await accounts.pump(tester);
    await openRemoveDialog(tester, 'Bob');

    await tester.tap(find.text(en.connectionForgetCheckbox));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    await confirm(tester);

    final registry = await accounts.auth.registry.load();
    expect(registry.find(accounts.bob.id), isNull);
    expect(
      (await profilesOver(accounts.auth).metadataFor(bobOrigin))?.pin,
      isNotNull,
    );
  });

  testWidgets('no offer while another account uses the server', (tester) async {
    await accounts.seed();
    await seedUser(
      accounts.auth,
      oauthServer230(),
      userId: 10,
      username: 'dave',
      displayName: 'Dave',
    );
    await trustBobsServer();
    await accounts.pump(tester);
    await openRemoveDialog(tester, 'Bob');

    expect(find.text(en.connectionForgetCheckbox), findsNothing);
    await confirm(tester);
    expect(
      (await profilesOver(accounts.auth).metadataFor(bobOrigin))?.pin,
      isNotNull,
    );
  });

  testWidgets('no offer for a server without settings', (tester) async {
    await accounts.seed();
    await accounts.pump(tester);
    await openRemoveDialog(tester, 'Bob');

    expect(find.text(en.connectionForgetCheckbox), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets(
    'on iOS the adaptive checkbox sits in a row that toggles it, at least '
    '48 dp tall, inside the Cupertino dialog',
    (tester) async {
      await accounts.seed();
      await trustBobsServer();
      await accounts.pump(tester);
      await openRemoveDialog(tester, 'Bob');

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.byType(CupertinoCheckbox), findsOneWidget);
      final row = find.ancestor(
        of: find.text(en.connectionForgetCheckbox),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
      await tester.tap(find.text(en.connectionForgetCheckbox));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CupertinoCheckbox>(find.byType(CupertinoCheckbox)).value,
        isFalse,
      );
      await tester.tap(find.text(en.removeAccountDialogConfirm));
      await tester.pumpAndSettle();
      expect(
        (await profilesOver(accounts.auth).metadataFor(bobOrigin))?.pin,
        isNotNull,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
