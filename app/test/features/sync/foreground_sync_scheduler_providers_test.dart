import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/sync/application/foreground_sync_scheduler_providers.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);

  testWidgets('the scheduler rests while nothing listens to its provider and '
      'goes on when the shell listens again', (tester) async {
    final auth = AuthFakes();
    await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now.toUtc()),
    );
    final data = SyncFakes(now: now);
    final container = ProviderContainer(
      overrides: [
        ...appOverrides(auth: auth, sync: data),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    final shell = container.listen(foregroundSyncSchedulerProvider, (_, _) {});
    while (shell.read() == null) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    shell.close();
    await tester.pump(const Duration(minutes: 5));
    expect(data.engine.refreshCalls, 0);

    final again = container.listen(foregroundSyncSchedulerProvider, (_, _) {});
    expect(again.read(), isNotNull);
    await tester.pump(const Duration(minutes: 1));
    expect(data.engine.refreshCalls, 1);

    // Before the test ends: a timer still pending there would fail it.
    again.close();
    container.dispose();
  });
}
