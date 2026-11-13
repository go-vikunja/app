import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_record.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_theme.dart';
import 'package:vikunja_mobile/features/home/presentation/home_shell.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 11, 13, 9);
  late AuthFakes auth;
  late SyncFakes sync;

  setUp(() {
    auth = AuthFakes();
    sync = SyncFakes(now: now);
  });

  testWidgets("the shell saves the previous app's dark theme to an account "
      'that follows the system', (tester) async {
    await rememberPreviousAppTheme(
      auth.preferences,
      theme: 'dark',
      server: fullServer270().rootUri,
    );

    await pumpSignedInApp(tester, auth: auth, sync: sync, now: now);

    expect(find.byType(HomeShell), findsOneWidget);
    expect(sync.shared.accountSettings.changes, [
      const UserSettingsChanges(colorSchema: ColorSchema.dark),
    ]);
    expect(sync.shared.settings.colorSchema, ColorSchema.dark);
    expect(auth.preferences.values.containsKey(previousAppThemeKey), isFalse);
  });

  testWidgets('without a pending theme nothing is saved', (tester) async {
    await pumpSignedInApp(tester, auth: auth, sync: sync, now: now);

    expect(find.byType(HomeShell), findsOneWidget);
    expect(sync.shared.accountSettings.calls, isEmpty);
  });

  testWidgets('an account on another server leaves the theme pending, and a '
      "switch to one on the previous app's server saves it", (tester) async {
    final bob = await auth.seedAccount(
      oauthServer230(),
      tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
      displayName: 'Bob',
      activate: false,
    );
    await rememberPreviousAppTheme(
      auth.preferences,
      theme: 'light',
      server: oauthServer230().rootUri,
    );
    await pumpSignedInApp(tester, auth: auth, sync: sync, now: now);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(sync.shared.accountSettings.calls, isEmpty);
    expect(auth.preferences.values.containsKey(previousAppThemeKey), isTrue);

    await containerOf(tester).read(accountRegistryProvider).setActive(bob.id);
    await tester.pumpAndSettle();

    expect(sync.shared.accountSettings.changes, [
      const UserSettingsChanges(colorSchema: ColorSchema.light),
    ]);
  });
}
