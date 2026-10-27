import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/core/widgets/widget_host.dart';
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';
import 'package:vikunja_mobile/core/widgets/widget_snapshot.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/widget_fakes.dart';

final DateTime widgetsNow = DateTime(2026, 10, 26, 9);

/// The signed-in app with the widgets' platform side and their builds
/// faked: projects (one archived), labels and saved filters to choose
/// from, and previews answered by the refresher's `previews`.
final class WidgetPagesHarness {
  new({this.launcherDeclinesPins = false}) {
    data.projects.all = [
      sampleProject(id: 1, title: 'Work', position: 1),
      sampleProject(id: 2, title: 'Inbox', position: 2),
      sampleProject(id: 3, title: 'Garage Sale', position: 3, parent: 1),
      sampleProject(id: 4, title: 'Old stuff', position: 4, archived: true),
    ];
    data.projects.savedFilters = [
      const SavedFilterRef(projectId: -3, title: 'Urgent'),
    ];
  }

  /// The launcher says it can pin widgets, then declines every request.
  final bool launcherDeclinesPins;
  final data = SyncFakes(now: widgetsNow);
  final host = FakeWidgetHost();
  final refresher = FakeWidgetRefresher();

  List<Override> get overrides => [
    widgetHostProvider.overrideWithValue(
      launcherDeclinesPins ? _DecliningPins(host) : host,
    ),
    widgetRefresherProvider.overrideWithValue(refresher),
  ];

  Future<void> seedLabels() async {
    await data.labels.create(const NewLabel(title: 'Errands'));
    await data.labels.create(
      const NewLabel(title: 'Calls', hexColor: '3a86ff'),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    String? location,
    List<Override> overrides = const [],
  }) async {
    await pumpSignedInApp(
      tester,
      sync: data,
      now: widgetsNow,
      overrides: [...this.overrides, ...overrides],
    );
    if (location != null) {
      unawaited(routerOf(tester).push(location));
      await tester.pumpAndSettle();
    }
  }

  GoRouter routerOf(WidgetTester tester) =>
      containerOf(tester).read(appRouterProvider);

  String activeAccountId(WidgetTester tester) =>
      containerOf(tester).read(accountsProvider).value!.activeAccountId!;
}

/// A preview of [config] with [rows] tasks, the first one overdue.
WidgetSnapshot samplePreview(
  WidgetConfig config, {
  required String title,
  int rows = 2,
  int total = 2,
  String? subtitle,
}) => WidgetSnapshot(
  key: config.key,
  accountId: config.accountId,
  state: WidgetSnapshotState.ok,
  title: title,
  subtitle: subtitle,
  generatedAt: widgetsNow,
  validUntil: widgetsNow.add(const Duration(hours: 15)),
  total: total,
  countLabel: '$total tasks',
  moreLabel: total > rows ? '+${total - rows} more' : null,
  empty: const WidgetText('Nothing due', body: 'Enjoy the quiet.'),
  rows: [
    for (var i = 0; i < rows; i++)
      WidgetRow(
        taskId: i + 1,
        title: 'Preview task ${i + 1} with a title long enough to wrap',
        dueLabel: i == 0 ? 'Yesterday' : 'Today, 17:00',
        tone: i == 0 ? WidgetDueTone.overdue : WidgetDueTone.today,
        canDone: i.isEven,
        semanticsLabel: 'Preview task ${i + 1}',
        doneLabel: 'Mark done',
        link: 'vikunja-dev.coderoftime.vikunja://widget/task/${i + 1}',
      ),
  ],
);

final class _DecliningPins implements WidgetHost {
  new(this._host);

  final FakeWidgetHost _host;

  @override
  Future<bool> canRequestPin() async => true;

  @override
  Future<bool> requestPin(WidgetConfig config) async {
    await _host.requestPin(config);
    return false;
  }

  @override
  Future<void> writeSnapshot(String key, String json) =>
      _host.writeSnapshot(key, json);

  @override
  Future<void> writeCatalog(String accountId, String json) =>
      _host.writeCatalog(accountId, json);

  @override
  Future<void> writeHost({
    required String? activeAccountId,
    required bool dynamicColor,
  }) => _host.writeHost(
    activeAccountId: activeAccountId,
    dynamicColor: dynamicColor,
  );

  @override
  Future<void> deleteForAccount(String accountId) =>
      _host.deleteForAccount(accountId);

  @override
  Future<Map<int, WidgetConfig?>> configs() => _host.configs();

  @override
  Future<void> saveConfig(int widgetId, WidgetConfig config) =>
      _host.saveConfig(widgetId, config);

  @override
  Future<Set<WidgetConfig>> displayedConfigs() => _host.displayedConfigs();

  @override
  Future<void> update(Set<String> keys) => _host.update(keys);

  @override
  Future<void> updateAll() => _host.updateAll();

  @override
  Future<List<WidgetDoneTap>> takeActions() => _host.takeActions();

  @override
  Future<void> ackActions(Iterable<String> ids) => _host.ackActions(ids);
}
