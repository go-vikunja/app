import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/previous_install.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/server_connections.dart';

void main() {
  late AuthFakes auth;
  final now = DateTime.utc(2026, 10, 9, 12);

  setUp(() => auth = AuthFakes());

  Future<AccountRegistryState> load({required AppPart part}) async {
    final container = ProviderContainer(
      overrides: [...auth.overrides, appPartProvider.overrideWithValue(part)],
    );
    addTearDown(container.dispose);
    final state = await container.read(accountsProvider.future);
    await pumpEventQueue();
    return state;
  }

  Future<bool> needsReauth(String accountId) async =>
      (await AccountRegistry(auth.preferences).find(accountId))!
          .account
          .needsReauth;

  test('the app purges what an earlier install left and flags an account '
      'without tokens', () async {
    final entry = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now),
    );
    await auth.tokenStore.delete(entry.id);

    await load(part: AppPart.app);

    expect(await needsReauth(entry.id), isTrue);
    expect(auth.preferences.values, contains(installMarkerKey));
  });

  test('a background run or notification action does neither: its fresh '
      "engine's first Keystore read is where a passing failure shows "
      '(decision log: Sessions)', () async {
    final entry = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now),
    );
    await auth.tokenStore.delete(entry.id);
    auth.preferences.values.remove(installMarkerKey);
    auth.secureStore.values['account.other.refresh_token'] = 'kept';

    for (final part in [
      AppPart.backgroundRun,
      AppPart.notificationAction,
      AppPart.widgetAction,
    ]) {
      final state = await load(part: part);

      expect(state.find(entry.id), isNotNull, reason: '$part');
      expect(await needsReauth(entry.id), isFalse, reason: '$part');
      expect(auth.secureStore.values, contains('account.other.refresh_token'));
      expect(auth.preferences.values, isNot(contains(installMarkerKey)));
    }
  });
}
