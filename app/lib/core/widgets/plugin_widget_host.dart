import 'package:rurana_widgets/rurana_widgets.dart';
import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/core/widgets/widget_host.dart';

/// [WidgetHost] over the in-repo plugin, which keeps the files in the
/// layout the native widgets read.
final class PluginWidgetHost implements WidgetHost {
  new(this._plugin);

  final RuranaWidgets _plugin;

  @override
  Future<void> writeSnapshot(String key, String json) async {
    await _plugin.writeSnapshot(key, json);
  }

  @override
  Future<void> writeCatalog(String accountId, String json) async {
    await _plugin.writeCatalog(accountId, json);
  }

  @override
  Future<void> writeHost({
    required String? activeAccountId,
    required bool dynamicColor,
    required String? linkKey,
  }) async {
    await _plugin.writeHost(
      activeAccountId: activeAccountId,
      dynamicColor: dynamicColor,
      linkKey: linkKey,
    );
  }

  @override
  Future<void> deleteForAccount(String accountId) =>
      _plugin.deleteForAccount(accountId);

  @override
  Future<void> deleteSnapshotsExcept(String accountId, Set<String> keys) async {
    for (final key in await _plugin.snapshotKeys(accountId: accountId)) {
      if (!keys.contains(key)) await _plugin.deleteSnapshot(key);
    }
  }

  @override
  Future<Map<int, WidgetConfig?>> configs() async => {
    for (final instance in await _plugin.configs())
      if (_configOf(instance.config) case final config?)
        instance.appWidgetId: config
      else if (instance.provider == WidgetProviderKind.list)
        instance.appWidgetId: null,
  };

  @override
  Future<void> saveConfig(int widgetId, WidgetConfig config) => _plugin
      .saveConfig(widgetId, snapshotKey: config.key, config: config.toJson());

  @override
  Future<Set<WidgetConfig>> displayedConfigs() async => {
    for (final key in await _plugin.displayedSnapshotKeys())
      ?WidgetConfig.fromKey(key),
  };

  @override
  Future<void> update(Set<String> keys) => _plugin.update(keys);

  @override
  Future<void> updateAll() => _plugin.updateAll();

  @override
  Future<bool> canRequestPin() => _plugin.canRequestPin();

  @override
  Future<bool> requestPin(WidgetConfig config) => _plugin.requestPin(
    config.kind is QuickAddKind
        ? WidgetProviderKind.quickAdd
        : WidgetProviderKind.list,
    snapshotKey: config.key,
    config: config.toJson(),
  );

  @override
  Future<List<WidgetDoneTap>> takeActions() async => [
    for (final action in await _plugin.takeActions())
      WidgetDoneTap(
        id: action.id,
        accountId: action.accountId,
        taskId: action.taskId,
        createdAt: action.createdAt,
      ),
  ];

  @override
  Future<void> ackActions(Iterable<String> ids) => _plugin.ackActions(ids);

  static WidgetConfig? _configOf(Map<String, Object?>? json) {
    if (json == null) return null;
    try {
      return WidgetConfig.fromJson(json);
    } on FormatException {
      return null;
    }
  }
}
