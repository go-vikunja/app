import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;
import 'package:vikunja_mobile/core/widgets/widget_config.dart';

/// What one account offers the native widget pickers (iOS's configuration
/// intent): the account, its lists with their snapshot keys and titles.
/// No secret; the titles are localized.
@immutable
final class WidgetCatalog {
  const new({
    required this.account,
    required this.generatedAt,
    required this.lists,
    required this.canAddTasks,
  });

  static const version = 1;

  final WidgetCatalogAccount account;
  final DateTime generatedAt;

  /// The smart lists first, then the projects (archived ones left out),
  /// the labels and the saved filters (none for a guest), each by title.
  final List<WidgetCatalogList> lists;

  /// Whether a writable project exists, for the quick add widget.
  final bool canAddTasks;

  Map<String, Object?> toJson() => {
    'v': version,
    'generatedAt': generatedAt.millisecondsSinceEpoch,
    'account': account.toJson(),
    'canAddTasks': canAddTasks,
    'quickAddKey': snapshotKey(account.id, const QuickAddKind()),
    'lists': [for (final list in lists) list.toJson()],
  };

  String encode() => jsonEncode(toJson());

  /// The JSON without [generatedAt].
  String contentFingerprint() => jsonEncode(toJson()..remove('generatedAt'));
}

@immutable
final class WidgetCatalogAccount {
  const new({
    required this.id,
    required this.name,
    required this.host,
    required this.isGuest,
    required this.supportsV2,
  });

  final String id;
  final String name;
  final String host;
  final bool isGuest;
  final bool supportsV2;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'host': host,
    'guest': isGuest,
    'v2': supportsV2,
  };
}

enum WidgetCatalogSection { smart, project, label, savedFilter }

/// One list a widget can show: its config in the same JSON as
/// [WidgetConfig] and the [key] its snapshot is stored under.
@immutable
final class WidgetCatalogList {
  const new({
    required this.config,
    required this.section,
    required this.title,
    this.color,
    this.writable,
    this.depth = 0,
    this.parent,
  });

  final WidgetConfig config;
  final WidgetCatalogSection section;
  final String title;

  /// `rrggbb`, without `#`.
  final String? color;

  /// For a project: whether tasks can be added to it.
  final bool? writable;

  /// For a project: its nesting in the project tree.
  final int depth;

  /// For a nested project: the titles above it, outermost first, so
  /// pickers that cannot indent tell same-named projects apart.
  final String? parent;

  String get key => config.key;

  Map<String, Object?> toJson() => {
    'key': key,
    ...config.kind.toJson(),
    'section': section.name,
    'title': title,
    'color': ?color,
    'writable': ?writable,
    if (depth > 0) 'depth': depth,
    'parent': ?parent,
  };
}
