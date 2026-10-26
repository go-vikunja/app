import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/core/time/today_provider.dart';

void main() {
  testWidgets('is the local date of the clock, turns over at midnight while '
      'the app is in front and tells only then', (tester) async {
    var now = DateTime(2026, 10, 26, 23, 58, 30);
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    final seen = <DateTime>[];
    container.listen(
      todayProvider,
      (_, today) => seen.add(today),
      fireImmediately: true,
    );

    now = DateTime(2026, 10, 26, 23, 59, 30);
    await tester.pump(ClockTick.period);
    now = DateTime(2026, 10, 27, 0, 0, 30);
    await tester.pump(ClockTick.period);
    now = DateTime(2026, 10, 27, 0, 1, 30);
    await tester.pump(ClockTick.period);

    expect(seen, [DateTime(2026, 10, 26), DateTime(2026, 10, 27)]);
    // Before the test ends: the tick's timer must not outlive it.
    container.dispose();
  });

  testWidgets('a clock in UTC still gives the local date', (tester) async {
    final now = DateTime(2026, 10, 26, 12);
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(now.toUtc)],
    );

    expect(container.read(todayProvider), DateTime(2026, 10, 26));
    container.dispose();
  });
}
