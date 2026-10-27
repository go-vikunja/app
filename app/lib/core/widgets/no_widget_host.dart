import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/core/widgets/widget_host.dart';

/// Where the platform has no home-screen widgets: nothing is stored and
/// nothing is placed.
final class NoWidgetHost implements WidgetHost {
  const new();

  @override
  Future<void> writeSnapshot(String key, String json) async {}

  @override
  Future<void> writeCatalog(String accountId, String json) async {}

  @override
  Future<void> writeHost({
    required String? activeAccountId,
    required bool dynamicColor,
    required String? linkKey,
  }) async {}

  @override
  Future<void> deleteForAccount(String accountId) async {}

  @override
  Future<void> deleteSnapshotsExcept(
    String accountId,
    Set<String> keys,
  ) async {}

  @override
  Future<Map<int, WidgetConfig?>> configs() async => const {};

  @override
  Future<void> saveConfig(int widgetId, WidgetConfig config) async {}

  @override
  Future<Set<WidgetConfig>> displayedConfigs() async => const {};

  @override
  Future<void> update(Set<String> keys) async {}

  @override
  Future<void> updateAll() async {}

  @override
  Future<bool> canRequestPin() async => false;

  @override
  Future<bool> requestPin(WidgetConfig config) async => false;

  @override
  Future<List<WidgetDoneTap>> takeActions() async => const [];

  @override
  Future<void> ackActions(Iterable<String> ids) async {}
}
