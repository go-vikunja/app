import 'package:flutter/foundation.dart' show immutable;
import 'package:vikunja_mobile/core/widgets/widget_config.dart';

/// The platform side of the home-screen widgets (`plugins/rurana_widgets`):
/// where snapshots and catalogs are stored for the native widgets, which
/// widgets are placed (Android), what they show, and the Done taps they
/// keep for the app. Works in every isolate.
abstract interface class WidgetHost {
  /// Stores [json] under [key] for the widgets that show it.
  Future<void> writeSnapshot(String key, String json);

  Future<void> writeCatalog(String accountId, String json);

  /// What an Android list widget without a config shows (the active
  /// account's Today) and whether the widgets follow the system colours.
  Future<void> writeHost({
    required String? activeAccountId,
    required bool dynamicColor,
  });

  /// Deletes the account's snapshots, catalog and the Done taps still
  /// queued for it; configs and iOS request markers stay, so the keys still
  /// on screen can get a tombstone.
  Future<void> deleteForAccount(String accountId);

  /// Deletes the account's snapshots other than those of [keys].
  Future<void> deleteSnapshotsExcept(String accountId, Set<String> keys);

  /// The placed widgets by widget id with their configs (Android): null for
  /// a list widget not set up, or whose config cannot be read, which shows
  /// the active account's Today; a Quick add widget without one, which
  /// needs none, is left out. Empty on iOS.
  Future<Map<int, WidgetConfig?>> configs();

  Future<void> saveConfig(int widgetId, WidgetConfig config);

  /// Every config a widget shows now: the placed ones', an unconfigured
  /// Android list widget's default, and on iOS what the extension recorded
  /// for a list whose snapshot it did not find.
  Future<Set<WidgetConfig>> displayedConfigs();

  /// Asks the OS to redraw the widgets that show one of [keys].
  Future<void> update(Set<String> keys);

  Future<void> updateAll();

  Future<bool> canRequestPin();

  /// Asks the launcher to place a widget with [config] (Android 8+); false
  /// where the launcher cannot.
  Future<bool> requestPin(WidgetConfig config);

  /// The Done taps the widgets keep for the app (Android's queue, the iOS
  /// outbox), oldest first; nothing is removed before [ackActions].
  Future<List<WidgetDoneTap>> takeActions();

  /// Deletes the taps once their Done is safely in the database.
  Future<void> ackActions(Iterable<String> ids);
}

/// One Done tap of a widget, as the native side keeps it until the app has
/// applied it (a file of the iOS extension's outbox, a line of Android's
/// queue; the plugin reads that JSON). [id] is unique per tap.
@immutable
final class WidgetDoneTap {
  const new({
    required this.id,
    required this.accountId,
    required this.taskId,
    required this.createdAt,
  });

  final String id;
  final String accountId;
  final int taskId;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is WidgetDoneTap &&
      other.id == id &&
      other.accountId == accountId &&
      other.taskId == taskId &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, accountId, taskId, createdAt);
}
