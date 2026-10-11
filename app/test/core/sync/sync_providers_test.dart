import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';

import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime.utc(2026, 10, 11, 12);

  test('preparing an account waits for its engine to report, after which '
      'its status is at hand', () async {
    final engine = FakeSyncEngine(
      initialStatus: SyncIdle(lastSyncedAt: now),
      restored: false,
    );
    final container = ProviderContainer(
      overrides: [syncEngineProvider.overrideWith((ref, _) => engine)],
    );
    addTearDown(container.dispose);

    var prepared = false;
    final preparing = prepareSyncStatus(
      container,
      'bob',
    ).then((_) => prepared = true);
    await pumpEventQueue();
    expect(prepared, isFalse);

    engine.emit(SyncIdle(lastSyncedAt: now));
    await preparing;

    expect(
      container.read(accountSyncStatusProvider('bob')).value,
      SyncIdle(lastSyncedAt: now),
    );
  });

  test('preparing never fails: not for an engine that never reports, nor for '
      'one that cannot be built', () async {
    final container = ProviderContainer(
      overrides: [
        syncEngineProvider.overrideWith(
          (ref, accountId) => accountId == 'gone'
              ? throw StateError('Account gone is not registered')
              : FakeSyncEngine(restored: false),
        ),
      ],
    );
    addTearDown(container.dispose);

    await prepareSyncStatus(
      container,
      'silent',
      timeout: const Duration(milliseconds: 10),
    );
    await prepareSyncStatus(container, 'gone');
  });
}
