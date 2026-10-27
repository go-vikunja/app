import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;
import 'package:vikunja_mobile/core/links/widget_link.dart';

/// What a home-screen widget shows. The JSON names match [WidgetListKind]
/// for the lists; [QuickAddKind] is only a button.
@immutable
sealed class WidgetKind {
  const new();

  /// Throws a [FormatException] for anything it does not know.
  factory fromJson(Map<String, Object?> json) {
    int id() => switch (json['id']) {
      final int id => id,
      _ => throw const FormatException('A widget kind without its id'),
    };
    return switch (json['kind']) {
      'today' => const TodayKind(),
      'overdue' => const OverdueKind(),
      'upcoming' => switch (json['days']) {
        final int days when upcomingDays.contains(days) => UpcomingKind(days),
        _ => throw const FormatException('Upcoming without 3, 7 or 14 days'),
      },
      'favorites' => const FavoritesKind(),
      'project' => ProjectTasksKind(id()),
      'label' => LabelTasksKind(id()),
      'savedFilter' => SavedFilterKind(id()),
      'quickAdd' => const QuickAddKind(),
      final kind => throw FormatException('Unknown widget kind $kind'),
    };
  }

  static const upcomingDays = [3, 7, 14];

  String get name;

  /// Its part of a snapshot key: letters, digits and `_` only, so the key
  /// is a safe file name on both platforms.
  String get keyPart;

  /// The app's list a tap on the widget's header opens; null for
  /// [QuickAddKind].
  WidgetListLink? listLink(String accountId);

  Map<String, Object?> toJson() => {'kind': name};
}

/// Overdue and due today, like the Overview's first sections.
final class TodayKind extends WidgetKind {
  const new();

  @override
  String get name => 'today';

  @override
  String get keyPart => 'today';

  @override
  WidgetListLink listLink(String accountId) =>
      WidgetListLink(accountId: accountId, kind: WidgetListKind.today);

  @override
  bool operator ==(Object other) => other is TodayKind;

  @override
  int get hashCode => (TodayKind).hashCode;
}

/// The overdue tasks and those due within the next [days].
final class UpcomingKind extends WidgetKind {
  const new(this.days);

  final int days;

  @override
  String get name => 'upcoming';

  @override
  String get keyPart => 'upcoming_$days';

  @override
  WidgetListLink listLink(String accountId) => WidgetListLink(
    accountId: accountId,
    kind: WidgetListKind.upcoming,
    days: days,
  );

  @override
  Map<String, Object?> toJson() => {...super.toJson(), 'days': days};

  @override
  bool operator ==(Object other) => other is UpcomingKind && other.days == days;

  @override
  int get hashCode => Object.hash(UpcomingKind, days);
}

final class OverdueKind extends WidgetKind {
  const new();

  @override
  String get name => 'overdue';

  @override
  String get keyPart => 'overdue';

  @override
  WidgetListLink listLink(String accountId) =>
      WidgetListLink(accountId: accountId, kind: WidgetListKind.overdue);

  @override
  bool operator ==(Object other) => other is OverdueKind;

  @override
  int get hashCode => (OverdueKind).hashCode;
}

/// The open tasks of the project's first list view, in its filter and sort.
final class ProjectTasksKind extends WidgetKind {
  const new(this.projectId);

  final int projectId;

  @override
  String get name => 'project';

  @override
  String get keyPart => 'project_$projectId';

  @override
  WidgetListLink listLink(String accountId) => WidgetListLink(
    accountId: accountId,
    kind: WidgetListKind.project,
    id: projectId,
  );

  @override
  Map<String, Object?> toJson() => {...super.toJson(), 'id': projectId};

  @override
  bool operator ==(Object other) =>
      other is ProjectTasksKind && other.projectId == projectId;

  @override
  int get hashCode => Object.hash(ProjectTasksKind, projectId);
}

final class LabelTasksKind extends WidgetKind {
  const new(this.labelId);

  final int labelId;

  @override
  String get name => 'label';

  @override
  String get keyPart => 'label_$labelId';

  @override
  WidgetListLink listLink(String accountId) => WidgetListLink(
    accountId: accountId,
    kind: WidgetListKind.label,
    id: labelId,
  );

  @override
  Map<String, Object?> toJson() => {...super.toJson(), 'id': labelId};

  @override
  bool operator ==(Object other) =>
      other is LabelTasksKind && other.labelId == labelId;

  @override
  int get hashCode => Object.hash(LabelTasksKind, labelId);
}

final class FavoritesKind extends WidgetKind {
  const new();

  @override
  String get name => 'favorites';

  @override
  String get keyPart => 'favorites';

  @override
  WidgetListLink listLink(String accountId) =>
      WidgetListLink(accountId: accountId, kind: WidgetListKind.favorites);

  @override
  bool operator ==(Object other) => other is FavoritesKind;

  @override
  int get hashCode => (FavoritesKind).hashCode;
}

/// [filterId] is the saved filter's own id, not its pseudo project id.
final class SavedFilterKind extends WidgetKind {
  const new(this.filterId);

  final int filterId;

  int get pseudoProjectId => -filterId - 1;

  @override
  String get name => 'savedFilter';

  @override
  String get keyPart => 'filter_$filterId';

  @override
  WidgetListLink listLink(String accountId) => WidgetListLink(
    accountId: accountId,
    kind: WidgetListKind.savedFilter,
    id: filterId,
  );

  @override
  Map<String, Object?> toJson() => {...super.toJson(), 'id': filterId};

  @override
  bool operator ==(Object other) =>
      other is SavedFilterKind && other.filterId == filterId;

  @override
  int get hashCode => Object.hash(SavedFilterKind, filterId);
}

final class QuickAddKind extends WidgetKind {
  const new();

  @override
  String get name => 'quickAdd';

  @override
  String get keyPart => 'quick_add';

  @override
  WidgetListLink? listLink(String accountId) => null;

  @override
  bool operator ==(Object other) => other is QuickAddKind;

  @override
  int get hashCode => (QuickAddKind).hashCode;
}

/// One widget's choice: an account and what of it to show. Widgets with
/// the same choice share one snapshot, stored under [key].
@immutable
final class WidgetConfig {
  const new({required this.accountId, required this.kind});

  /// Throws a [FormatException] for a config it cannot read.
  factory fromJson(Map<String, Object?> json) => switch (json['account']) {
    final String accountId when accountId.isNotEmpty => WidgetConfig(
      accountId: accountId,
      kind: WidgetKind.fromJson(json),
    ),
    _ => throw const FormatException('A widget config without its account'),
  };

  factory decode(String source) => switch (jsonDecode(source)) {
    final Map<String, Object?> json => WidgetConfig.fromJson(json),
    _ => throw const FormatException('A widget config is no JSON object'),
  };

  /// The inverse of [key]; null for a key no config has.
  static WidgetConfig? fromKey(String key) {
    final dot = key.indexOf('.');
    if (dot <= 0) return null;
    final part = key.substring(dot + 1);
    final numbered = _numberedPart.firstMatch(part);
    final id = numbered == null ? null : int.tryParse(numbered[2]!);
    final kind = switch ((numbered?[1], id)) {
      (null, _) => switch (part) {
        'today' => const TodayKind(),
        'overdue' => const OverdueKind(),
        'favorites' => const FavoritesKind(),
        'quick_add' => const QuickAddKind(),
        _ => null,
      },
      (_, null) => null,
      ('upcoming', final days?) when WidgetKind.upcomingDays.contains(days) =>
        UpcomingKind(days),
      ('project', final id?) => ProjectTasksKind(id),
      ('label', final id?) => LabelTasksKind(id),
      ('filter', final id?) => SavedFilterKind(id),
      _ => null,
    };
    return kind == null
        ? null
        : WidgetConfig(accountId: key.substring(0, dot), kind: kind);
  }

  static final _numberedPart = RegExp(
    r'^(upcoming|project|label|filter)_([0-9]{1,15})$',
  );

  static const version = 1;

  final String accountId;
  final WidgetKind kind;

  String get key => snapshotKey(accountId, kind);

  Map<String, Object?> toJson() => {
    'v': version,
    'account': accountId,
    ...kind.toJson(),
  };

  String encode() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is WidgetConfig &&
      other.accountId == accountId &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(accountId, kind);

  @override
  String toString() => 'WidgetConfig($key)';
}

/// `<accountId>.<keyPart>`, the plugin's layout: an Android list widget
/// that has no config yet shows `<accountId>.today`.
String snapshotKey(String accountId, WidgetKind kind) =>
    '$accountId.${kind.keyPart}';
