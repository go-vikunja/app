import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/activity/activity_notifier.dart';
import 'package:vikunja_mobile/core/activity/activity_providers.dart';
import 'package:vikunja_mobile/core/activity/activity_tray.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_os_ids.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/notification_fakes.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final noon = DateTime.utc(2026, 10, 13, 12);
  late AuthFakes auth;
  late ProviderContainer container;
  late FakeNotificationGateway gateway;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
    );
    auth = AuthFakes();
    final files = FakeAccountDatabaseFiles();
    container = ProviderContainer(
      overrides: [
        ...auth.overrides,
        accountDatabaseFilesProvider.overrideWithValue(files),
        openDatabasesProvider.overrideWithValue(
          OpenDatabases(
            files,
            open: (_, _) => AppDatabase(NativeDatabase.memory()),
          ),
        ),
        readClientProvider.overrideWith((ref, _) => FakeSyncClient()),
        writeClientProvider.overrideWith((ref, _) => FakeWriteClient()),
        syncEngineProvider.overrideWith((ref, _) => FakeSyncEngine()),
        clockProvider.overrideWithValue(() => noon),
        notificationGatewayProvider.overrideWithValue(
          gateway = FakeNotificationGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('the foreground sync keeps "Sign in again" for a session another '
      "isolate ended after this one's registry read", () async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: noon),
    );
    final bob = await auth.seedAccount(
      oauthServer230(),
      tokens: issueTokens(issuedAt: noon, userId: 8, username: 'bob'),
      activate: false,
    );
    final carol = await auth.seedAccount(
      oauthServer230(),
      tokens: issueTokens(issuedAt: noon, userId: 9, username: 'carol'),
      activate: false,
    );
    await container.read(accountsProvider.future);
    // What a background run stored through its own registry and notifier.
    for (final ended in [alice, bob]) {
      await AccountRegistry(auth.preferences).markNeedsReauth(ended.id);
    }
    for (final entry in [alice, bob, carol]) {
      await auth.preferences.setString(
        ActivityNotifier.sessionEndedKey(entry.id),
        'true',
      );
    }
    String? sessionEnded(RegisteredAccount entry) =>
        auth.preferences.values[ActivityNotifier.sessionEndedKey(entry.id)];

    container.read(foregroundActivityProvider).onForeground(timed: false);
    // Carol comes last.
    for (var i = 0; i < 400 && sessionEnded(carol) != null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    expect(sessionEnded(carol), isNull);
    expect(sessionEnded(alice), 'true');
    expect(sessionEnded(bob), 'true');
    expect(gateway.cancelled, [
      notificationOsIdFor(carol.id, ActivityTray.sessionKey(carol.id)),
    ]);
  });
}
