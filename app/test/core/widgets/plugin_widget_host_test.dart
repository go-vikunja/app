import 'package:flutter_test/flutter_test.dart';
import 'package:rurana_widgets/rurana_widgets.dart';
import 'package:rurana_widgets/testing.dart';
import 'package:vikunja_mobile/core/widgets/plugin_widget_host.dart';
import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/core/widgets/widget_host.dart';

// The adapter over the plugin's in-memory double: the app's configs and
// keys in the plugin's file layout.
void main() {
  const alice = '0123456789abcdef0123456789abcdef';
  late MemoryRuranaWidgets plugin;
  late PluginWidgetHost host;

  setUp(() {
    plugin = MemoryRuranaWidgets(
      instances: const [
        WidgetInstance(appWidgetId: 1, provider: WidgetProviderKind.list),
        WidgetInstance(appWidgetId: 2, provider: WidgetProviderKind.quickAdd),
      ],
      pinSupported: true,
    );
    host = PluginWidgetHost(plugin);
  });

  test('saves a config under its snapshot key and reads it back', () async {
    const config = WidgetConfig(accountId: alice, kind: ProjectTasksKind(12));

    await host.saveConfig(1, config);

    expect(plugin.instances.first.snapshotKey, '$alice.project_12');
    expect(await host.configs(), {1: config});
  });

  test('lists a list widget without a readable config as not set up, and '
      'leaves out a Quick add widget without one', () async {
    plugin.instances.addAll(const [
      WidgetInstance(
        appWidgetId: 3,
        provider: WidgetProviderKind.list,
        snapshotKey: 'x.today',
        config: {'kind': 'calendar'},
      ),
      WidgetInstance(appWidgetId: 4, provider: WidgetProviderKind.unknown),
    ]);

    expect(await host.configs(), {1: null, 3: null});
  });

  test("shows the placed configs, an unconfigured widget's default and the "
      "iOS extension's requests", () async {
    await host.saveConfig(
      2,
      const WidgetConfig(accountId: alice, kind: QuickAddKind()),
    );
    await host.writeHost(activeAccountId: alice, dynamicColor: false);
    plugin.requestedKeys.addAll({'$alice.label_3', 'not a key of ours'});

    expect(await host.displayedConfigs(), {
      const WidgetConfig(accountId: alice, kind: QuickAddKind()),
      const WidgetConfig(accountId: alice, kind: TodayKind()),
      const WidgetConfig(accountId: alice, kind: LabelTasksKind(3)),
    });
    expect(plugin.host, (activeAccountId: alice, dynamicColor: false));
  });

  test('asks the launcher for the right widget, with its config', () async {
    await host.requestPin(
      const WidgetConfig(accountId: alice, kind: QuickAddKind()),
    );
    await host.requestPin(
      const WidgetConfig(accountId: alice, kind: UpcomingKind(7)),
    );

    expect(
      [for (final request in plugin.pinRequests) request.provider],
      [WidgetProviderKind.quickAdd, WidgetProviderKind.list],
    );
    expect(plugin.pinRequests.last.snapshotKey, '$alice.upcoming_7');
    expect(plugin.pinRequests.last.config, {
      'v': 1,
      'account': alice,
      'kind': 'upcoming',
      'days': 7,
    });
  });

  test('hands over the Done taps and acknowledges them', () async {
    final at = DateTime.utc(2026, 10, 26, 9);
    plugin.actions.add(
      WidgetAction(id: 'a', accountId: alice, taskId: -4, createdAt: at),
    );

    expect(await host.takeActions(), [
      WidgetDoneTap(id: 'a', accountId: alice, taskId: -4, createdAt: at),
    ]);
    await host.ackActions(['a']);
    expect(plugin.actions, isEmpty);
  });

  test('writes snapshots and catalogs and deletes an account', () async {
    await host.writeSnapshot('$alice.today', '{}');
    await host.writeCatalog(alice, '{}');
    await host.update({'$alice.today'});

    await host.deleteForAccount(alice);

    expect(plugin.snapshots, isEmpty);
    expect(plugin.catalogs, isEmpty);
    expect(plugin.updates, [
      ['$alice.today'],
    ]);
  });
}
