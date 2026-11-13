import 'dart:io';

import 'package:vikunja_widgets/src/vikunja_widgets.dart';
import 'package:vikunja_widgets/src/widget_models.dart';

typedef WidgetHostState = ({
  String? activeAccountId,
  bool dynamicColor,
  String? linkKey,
});

typedef PinRequest = ({
  WidgetProviderKind provider,
  String? snapshotKey,
  Map<String, Object?>? config,
});

/// In-memory [VikunjaWidgets] for app tests.
final class MemoryVikunjaWidgets implements VikunjaWidgets {
  new({List<WidgetInstance> instances = const [], this.pinSupported = false})
    : instances = [...instances];

  final Map<String, String> snapshots = {};
  final Map<String, String> catalogs = {};
  WidgetHostState? host;
  final List<WidgetInstance> instances;

  /// iOS request markers written by the extension.
  final Set<String> requestedKeys = {};
  final List<WidgetAction> actions = [];
  final List<List<String>> updates = [];
  int updateAllCalls = 0;
  bool pinSupported;
  final List<PinRequest> pinRequests = [];

  @override
  Future<Directory?> widgetsDirectory() async => null;

  @override
  Future<Directory?> appGroupDirectory() async => null;

  @override
  Future<bool> writeSnapshot(String key, String json) async {
    _checkKey(key);
    if (snapshots[key] == json) return false;
    snapshots[key] = json;
    return true;
  }

  @override
  Future<String?> readSnapshot(String key) async => snapshots[key];

  @override
  Future<void> deleteSnapshot(String key) async => snapshots.remove(key);

  @override
  Future<List<String>> snapshotKeys({String? accountId}) async {
    return [
      for (final key in snapshots.keys)
        if (accountId == null || isSnapshotKeyOf(key, accountId)) key,
    ]..sort();
  }

  @override
  Future<bool> writeCatalog(String accountId, String json) async {
    if (catalogs[accountId] == json) return false;
    catalogs[accountId] = json;
    return true;
  }

  @override
  Future<String?> readCatalog(String accountId) async => catalogs[accountId];

  @override
  Future<bool> writeHost({
    required String? activeAccountId,
    required bool dynamicColor,
    String? linkKey,
  }) async {
    final next = (
      activeAccountId: activeAccountId,
      dynamicColor: dynamicColor,
      linkKey: linkKey,
    );
    if (host == next) return false;
    host = next;
    return true;
  }

  @override
  Future<void> deleteForAccount(String accountId) async {
    catalogs.remove(accountId);
    snapshots.removeWhere((key, _) => isSnapshotKeyOf(key, accountId));
    actions.removeWhere((action) => action.accountId == accountId);
  }

  @override
  Future<List<WidgetInstance>> configs() async => [...instances];

  @override
  Future<void> saveConfig(
    int appWidgetId, {
    required String? snapshotKey,
    required Map<String, Object?> config,
  }) async {
    if (config.containsKey('version') || config.containsKey('key')) {
      throw ArgumentError.value(config, 'config', 'uses a reserved field');
    }
    if (snapshotKey != null) _checkKey(snapshotKey);
    final index = instances.indexWhere(
      (instance) => instance.appWidgetId == appWidgetId,
    );
    final saved = WidgetInstance(
      appWidgetId: appWidgetId,
      provider: index < 0
          ? WidgetProviderKind.unknown
          : instances[index].provider,
      snapshotKey: snapshotKey,
      config: Map.unmodifiable(config),
    );
    if (index < 0) {
      instances.add(saved);
    } else {
      instances[index] = saved;
    }
  }

  @override
  Future<Set<String>> displayedSnapshotKeys() async {
    final keys = {
      for (final instance in instances) ?instance.snapshotKey,
      ...requestedKeys,
    };
    final activeAccountId = host?.activeAccountId;
    if (activeAccountId != null &&
        instances.any(
          (instance) =>
              instance.provider == WidgetProviderKind.list &&
              !instance.isConfigured,
        )) {
      keys.add(defaultSnapshotKey(activeAccountId));
    }
    return keys;
  }

  @override
  Future<void> update(Iterable<String> keys) async {
    final list = keys.toSet().toList();
    if (list.isNotEmpty) updates.add(list);
  }

  @override
  Future<void> updateAll() async => updateAllCalls++;

  @override
  Future<bool> canRequestPin() async => pinSupported;

  @override
  Future<bool> requestPin(
    WidgetProviderKind provider, {
    String? snapshotKey,
    Map<String, Object?>? config,
  }) async {
    if (provider == WidgetProviderKind.unknown) {
      throw ArgumentError.value(provider, 'provider');
    }
    if (snapshotKey != null) _checkKey(snapshotKey);
    if (!pinSupported) return false;
    pinRequests.add((
      provider: provider,
      snapshotKey: snapshotKey,
      config: config,
    ));
    return true;
  }

  @override
  Future<List<WidgetAction>> takeActions() async => [...actions]
    ..sort(
      (a, b) => a.createdAt != b.createdAt
          ? a.createdAt.compareTo(b.createdAt)
          : a.id.compareTo(b.id),
    );

  @override
  Future<void> ackActions(Iterable<String> ids) async {
    final acked = ids.toSet();
    actions.removeWhere((action) => acked.contains(action.id));
  }

  void _checkKey(String key) {
    if (!snapshotKeyPattern.hasMatch(key)) {
      throw ArgumentError.value(key, 'key', 'not a snapshot key');
    }
  }
}
