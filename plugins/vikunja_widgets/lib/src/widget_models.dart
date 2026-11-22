import 'package:flutter/foundation.dart';

const appGroupId = 'group.io.vikunja.app';

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
    this.followsActiveAccount = true,
  });

  final int appWidgetId;
  final WidgetProviderKind provider;

  /// False for a list widget placed with the previous Vikunja app, which
  /// asks to be set up instead of showing the active account's Today.
  final bool followsActiveAccount;

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
      other.followsActiveAccount == followsActiveAccount &&
      _sameJson(other.config, config);

  @override
  int get hashCode =>
      Object.hash(appWidgetId, provider, snapshotKey, followsActiveAccount);

  @override
  String toString() =>
      'WidgetInstance($appWidgetId, ${provider.name}, $snapshotKey, '
      'followsActiveAccount: $followsActiveAccount)';
}

@immutable
final class WidgetAction {
  const new({
    required this.id,
    required this.accountId,
    required this.taskId,
    required this.createdAt,
    this.shown,
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
        createdAt: _instant(createdAt)!,
        shown: switch (json['version']) {
          final num version when version >= showsRow => (
            dueAt: _instant(json['dueAt']),
          ),
          _ => null,
        },
      );
    }
    throw const FormatException('Not a widget action');
  }

  /// The version from which an entry says what its row showed; one before
  /// it has no [shown].
  static const showsRow = 2;

  final String id;
  final String accountId;

  /// Negative for a task the server has not created yet (decision log: Outbox).
  final int taskId;
  final DateTime createdAt;

  /// What the tapped row showed: its due date, null for none. Null for a
  /// tap written before the widgets recorded it.
  final ({DateTime? dueAt})? shown;

  Map<String, Object?> toJson() => {
    'version': shown == null ? 1 : showsRow,
    'id': id,
    'accountId': accountId,
    'taskId': taskId,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'dueAt': ?shown?.dueAt?.millisecondsSinceEpoch,
  };

  // A writer with fractional milliseconds (Foundation's date encoding)
  // must not lose its tap.
  static DateTime? _instant(Object? milliseconds) => switch (milliseconds) {
    final num ms when ms.isFinite => DateTime.fromMillisecondsSinceEpoch(
      ms.round(),
      isUtc: true,
    ),
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is WidgetAction &&
      other.id == id &&
      other.accountId == accountId &&
      other.taskId == taskId &&
      other.createdAt == createdAt &&
      other.shown == shown;

  @override
  int get hashCode => Object.hash(id, accountId, taskId, createdAt, shown);

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
