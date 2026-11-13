import 'package:flutter_riverpod/misc.dart';
import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/core/widgets/widget_host.dart';
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';
import 'package:vikunja_mobile/core/widgets/widget_publisher.dart';
import 'package:vikunja_mobile/core/widgets/widget_refresher.dart';
import 'package:vikunja_mobile/core/widgets/widget_snapshot.dart';

/// For screen tests, which fake everything below the screens: the shell's
/// widget work does nothing (no database opened, no plugin called), and a
/// sign-out wipes an in-memory host. The host and the refresher stay free
/// for a test to override.
List<Override> quietWidgetOverrides() => [
  accountWidgetPublishersProvider.overrideWithValue(const {}),
  widgetTapImporterProvider.overrideWithValue(WidgetTapImporter(() async {})),
  widgetHostSettingsProvider.overrideWith((ref) async {}),
  widgetPublishersProvider.overrideWithValue(
    WidgetPublishers(
      host: FakeWidgetHost(),
      removedSnapshot: (key, accountId) => WidgetSnapshot(
        key: key,
        accountId: accountId,
        state: WidgetSnapshotState.accountRemoved,
        title: 'Account removed',
        generatedAt: DateTime.utc(2026),
        validUntil: DateTime.utc(2036),
      ),
    ),
  ),
];

/// The platform side of the widgets in memory: what was written, deleted
/// and redrawn, the placed widgets' configs and the Done taps.
final class FakeWidgetHost implements WidgetHost {
  /// The stored snapshot JSON by key.
  final snapshots = <String, String>{};

  /// The stored catalog JSON by account id.
  final catalogs = <String, String>{};

  /// Null for a list widget not set up yet.
  final placed = <int, WidgetConfig?>{};

  /// The ids of [placed] that the previous app placed.
  final previousApp = <int>{};

  /// Shown besides [placed], as an unconfigured Android widget's default or
  /// an iOS extension's request does.
  final requested = <WidgetConfig>{};
  final actions = <WidgetDoneTap>[];
  ({String? activeAccountId, bool dynamicColor})? hostFile;
  String? hostLinkKey;

  /// Every call in order, e.g. `writeSnapshot <key>`, `update <keys>`.
  final calls = <String>[];
  final updatedKeys = <Set<String>>[];
  final pinRequests = <WidgetConfig>[];
  bool pinSupported = true;

  /// Thrown by every write while set.
  Exception? failure;

  /// Thrown by [configs] while set.
  Exception? configsFailure;

  WidgetSnapshot? snapshot(String key) => switch (snapshots[key]) {
    final json? => WidgetSnapshot.decode(json),
    null => null,
  };

  int writesOf(String key) =>
      calls.where((call) => call == 'writeSnapshot $key').length;

  void _fail() {
    if (failure case final failure?) throw failure;
  }

  @override
  Future<void> writeSnapshot(String key, String json) async {
    _fail();
    calls.add('writeSnapshot $key');
    snapshots[key] = json;
  }

  @override
  Future<void> writeCatalog(String accountId, String json) async {
    _fail();
    calls.add('writeCatalog $accountId');
    catalogs[accountId] = json;
  }

  @override
  Future<void> writeHost({
    required String? activeAccountId,
    required bool dynamicColor,
    required String? linkKey,
  }) async {
    _fail();
    calls.add('writeHost $activeAccountId $dynamicColor');
    hostFile = (activeAccountId: activeAccountId, dynamicColor: dynamicColor);
    hostLinkKey = linkKey;
  }

  @override
  Future<void> deleteForAccount(String accountId) async {
    _fail();
    calls.add('deleteForAccount $accountId');
    snapshots.removeWhere((key, _) => key.startsWith('$accountId.'));
    catalogs.remove(accountId);
    actions.removeWhere((tap) => tap.accountId == accountId);
  }

  @override
  Future<void> deleteSnapshotsExcept(String accountId, Set<String> keys) async {
    _fail();
    calls.add('deleteSnapshotsExcept $accountId');
    snapshots.removeWhere(
      (key, _) => key.startsWith('$accountId.') && !keys.contains(key),
    );
  }

  @override
  Future<Map<int, WidgetConfig?>> configs() async {
    if (configsFailure case final failure?) throw failure;
    return Map.of(placed);
  }

  @override
  Future<Set<int>> previousAppWidgets() async =>
      previousApp.where(placed.containsKey).toSet();

  @override
  Future<void> saveConfig(int widgetId, WidgetConfig config) async {
    _fail();
    calls.add('saveConfig $widgetId');
    placed[widgetId] = config;
  }

  @override
  Future<Set<WidgetConfig>> displayedConfigs() async => {
    ...placed.values.nonNulls,
    ...requested,
  };

  @override
  Future<void> update(Set<String> keys) async {
    calls.add('update ${(keys.toList()..sort()).join(',')}');
    updatedKeys.add(keys);
  }

  @override
  Future<void> updateAll() async => calls.add('updateAll');

  @override
  Future<bool> canRequestPin() async => pinSupported;

  @override
  Future<bool> requestPin(WidgetConfig config) async {
    calls.add('requestPin ${config.key}');
    pinRequests.add(config);
    return pinSupported;
  }

  @override
  Future<List<WidgetDoneTap>> takeActions() async {
    calls.add('takeActions');
    return List.of(actions);
  }

  @override
  Future<void> ackActions(Iterable<String> ids) async {
    final acked = ids.toSet();
    calls.add('ackActions ${(acked.toList()..sort()).join(',')}');
    actions.removeWhere((tap) => acked.contains(tap.id));
  }
}

/// Records what the app asked of the widgets; [previews] answers
/// [preview].
final class FakeWidgetRefresher implements WidgetRefresher {
  final refreshed = <String>[];
  int refreshedAll = 0;
  final published = <WidgetConfig>[];
  final previewed = <WidgetConfig>[];
  final previews = <WidgetConfig, WidgetSnapshot>{};

  @override
  Future<void> refresh(String accountId) async => refreshed.add(accountId);

  @override
  Future<void> refreshAll() async => refreshedAll++;

  @override
  Future<void> publish(WidgetConfig config) async => published.add(config);

  @override
  Future<WidgetSnapshot?> preview(WidgetConfig config) async {
    previewed.add(config);
    return previews[config];
  }
}
