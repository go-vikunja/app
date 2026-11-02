import 'package:flutter/foundation.dart';

const ruranaAppGroupId = 'group.dev.coderoftime.rurana';

final snapshotKeyPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,159}$');

String snapshotKeyPrefix(String accountId) => '$accountId.';

/// What an Android list widget without a config shows: the Today list of
/// host.json's active account.
String defaultSnapshotKey(String accountId) =>
    '${snapshotKeyPrefix(accountId)}today';

bool isSnapshotKeyOf(String key, String accountId) =>
    key.startsWith(snapshotKeyPrefix(accountId));

enum WidgetProviderKind {
  list,
  quickAdd,
  unknown;

  static WidgetProviderKind fromName(Object? name) =>
      values.firstWhere((kind) => kind.name == name, orElse: () => unknown);
}

@immutable
final class WidgetInstance {
  const new({
    required this.appWidgetId,
    required this.provider,
    this.snapshotKey,
    this.config,
  });

  final int appWidgetId;
  final WidgetProviderKind provider;

  /// The config file's `key`: the snapshot the widget shows (for Quick add
  /// its account's), null for an instance that has no config yet.
  final String? snapshotKey;
  final Map<String, Object?>? config;

  bool get isConfigured => config != null;

  @override
  bool operator ==(Object other) =>
      other is WidgetInstance &&
      other.appWidgetId == appWidgetId &&
      other.provider == provider &&
      other.snapshotKey == snapshotKey &&
      _sameJson(other.config, config);

  @override
  int get hashCode => Object.hash(appWidgetId, provider, snapshotKey);

  @override
  String toString() =>
      'WidgetInstance($appWidgetId, ${provider.name}, $snapshotKey)';
}

@immutable
final class WidgetAction {
  const new({
    required this.id,
    required this.accountId,
    required this.taskId,
    required this.createdAt,
  });

  factory fromJson(Map<String, Object?> json) {
    if (json
        case {
          'id': final String id,
          'accountId': final String accountId,
          'taskId': final int taskId,
          'createdAt': final num createdAt,
        }
        when id.isNotEmpty && accountId.isNotEmpty && createdAt.isFinite) {
      return WidgetAction(
        id: id,
        accountId: accountId,
        taskId: taskId,
        // A writer with fractional milliseconds (Foundation's date
        // encoding) must not lose its tap.
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          createdAt.round(),
          isUtc: true,
        ),
      );
    }
    throw const FormatException('Not a widget action');
  }

  static const version = 1;

  final String id;
  final String accountId;

  /// Negative for a task the server has not created yet (D35).
  final int taskId;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'version': version,
    'id': id,
    'accountId': accountId,
    'taskId': taskId,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  @override
  bool operator ==(Object other) =>
      other is WidgetAction &&
      other.id == id &&
      other.accountId == accountId &&
      other.taskId == taskId &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, accountId, taskId, createdAt);

  // Task titles never appear here, so the action may be logged.
  @override
  String toString() => 'WidgetAction($id, $accountId, $taskId)';
}

bool _sameJson(Object? a, Object? b) => switch ((a, b)) {
  (final Map<Object?, Object?> x, final Map<Object?, Object?> y) =>
    x.length == y.length &&
        x.keys.every((key) => y.containsKey(key) && _sameJson(x[key], y[key])),
  (final List<Object?> x, final List<Object?> y) =>
    x.length == y.length &&
        Iterable<int>.generate(x.length).every((i) => _sameJson(x[i], y[i])),
  _ => a == b,
};
