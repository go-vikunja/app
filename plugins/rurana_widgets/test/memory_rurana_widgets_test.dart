import 'package:flutter_test/flutter_test.dart';
import 'package:rurana_widgets/rurana_widgets.dart';
import 'package:rurana_widgets/testing.dart';

void main() {
  test('behaves like the real bridge for the publisher', () async {
    final widgets = MemoryRuranaWidgets(
      instances: const [
        WidgetInstance(appWidgetId: 1, provider: WidgetProviderKind.list),
      ],
      pinSupported: true,
    );

    expect(await widgets.writeSnapshot('a.today', '{}'), isTrue);
    expect(await widgets.writeSnapshot('a.today', '{}'), isFalse);
    expect(() => widgets.writeSnapshot('a/b', '{}'), throwsArgumentError);
    await widgets.writeHost(activeAccountId: 'a', dynamicColor: true);
    expect(await widgets.displayedSnapshotKeys(), {'a.today'});

    await widgets.saveConfig(
      1,
      snapshotKey: 'b.overdue',
      config: const {'account': 'b'},
    );
    expect(await widgets.displayedSnapshotKeys(), {'b.overdue'});
    expect((await widgets.configs()).single.provider, WidgetProviderKind.list);

    widgets.actions.addAll([
      WidgetAction(
        id: '2',
        accountId: 'b',
        taskId: 1,
        createdAt: DateTime.utc(2026),
      ),
      WidgetAction(
        id: '1',
        accountId: 'a',
        taskId: 1,
        createdAt: DateTime.utc(2026),
      ),
    ]);
    expect((await widgets.takeActions()).map((action) => action.id), [
      '1',
      '2',
    ]);
    await widgets.deleteForAccount('a');
    expect(await widgets.snapshotKeys(), isEmpty);
    await widgets.ackActions(['2']);
    expect(await widgets.takeActions(), isEmpty);

    await widgets.update(['b.overdue', 'b.overdue']);
    await widgets.update(const []);
    expect(widgets.updates, [
      ['b.overdue'],
    ]);
    expect(
      await widgets.requestPin(
        WidgetProviderKind.list,
        snapshotKey: 'a.overdue',
        config: const {'kind': 'overdue'},
      ),
      isTrue,
    );
    expect(widgets.pinRequests.single.provider, WidgetProviderKind.list);
    expect(widgets.pinRequests.single.snapshotKey, 'a.overdue');
  });
}
