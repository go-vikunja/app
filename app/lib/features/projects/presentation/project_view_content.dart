import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';

/// What a project's view shows: what its kind reads, with the view, the
/// kind of its filter and the preferences it was read for, so it can stay
/// on screen while another view or its preferences load.
@immutable
sealed class ProjectViewContent {
  const new({
    required this.view,
    required this.kind,
    required this.preferences,
  });

  /// Null for a project without views.
  final ProjectView? view;
  final ViewFilterKind kind;
  final ViewPreferences preferences;

  /// When the view was last downloaded; null before its first download.
  DateTime? get loadedAt;
}

/// The tasks of a list, table or Gantt view.
sealed class TaskViewContent extends ProjectViewContent {
  const new(
    this.source, {
    required super.view,
    required super.kind,
    required super.preferences,
  });

  final ProjectListSource source;

  @override
  DateTime? get loadedAt => source.snapshot.loadedAt;
}

/// A list view's tasks, which a project without views shows too.
final class ListViewContent extends TaskViewContent {
  const new(
    super.source, {
    required super.view,
    required super.kind,
    required super.preferences,
  });
}

final class TableViewContent extends TaskViewContent {
  const new(
    super.source, {
    required super.view,
    required super.kind,
    required super.preferences,
  });
}

/// A Gantt view's tasks of its range (`timelineSourceProvider`).
final class TimelineViewContent extends TaskViewContent {
  const new(
    super.source, {
    required super.view,
    required super.kind,
    required super.preferences,
  });
}

/// A kanban view's board.
final class BoardViewContent extends ProjectViewContent {
  const new(
    this.source, {
    required super.view,
    required super.kind,
    required super.preferences,
  });

  final BoardSource source;

  @override
  DateTime? get loadedAt => source.loadedAt;
}

/// What the project screen shows of its view this build: `data` for the
/// body, the `content` the selection takes, and `settled`, the view's own
/// content just read, once its source is not loading.
typedef ProjectViewShown = ({
  AsyncValue<ProjectViewContent> data,
  ProjectViewContent? content,
  ProjectViewContent? settled,
});

/// A view's source as its kind watches it, and the content its value
/// makes.
final class WatchedViewSource<S extends Object> {
  const new(this._source, this._content);

  final AsyncValue<S> _source;
  final ProjectViewContent Function(
    S source, {
    required ProjectView? view,
    required ViewFilterKind kind,
    required ViewPreferences preferences,
  })
  _content;

  /// What shows of the source, [ready] once the view shown can no longer
  /// change, for a screen that showed [last] before: once the source is
  /// not loading, its value as read for [view], [kind] and [preferences];
  /// while it loads, [last] when read from the same repository
  /// ([sameRepository]); else its loading or failure, and for the
  /// selection the value it may still carry, as of [last].
  ProjectViewShown show({
    required bool ready,
    required ProjectViewContent? last,
    required bool sameRepository,
    required ProjectView? view,
    required ViewFilterKind kind,
    required ViewPreferences preferences,
  }) {
    final current = ready ? _source : AsyncLoading<S>();
    switch (current) {
      // Not while a failed load is retried: the rows of another view would
      // pass for this one's.
      case AsyncLoading(hasError: false) when last != null && sameRepository:
        return (data: AsyncData(last), content: last, settled: null);
      case AsyncValue(:final value?) when current is! AsyncLoading:
        final content = _content(
          value,
          view: view,
          kind: kind,
          preferences: preferences,
        );
        return (data: AsyncData(content), content: content, settled: content);
      case AsyncError(:final error, :final stackTrace):
        return (
          data: AsyncError(error, stackTrace),
          content: null,
          settled: null,
        );
      case AsyncValue(:final value):
        // Only a content of this kind can be built, so not for a last view
        // of another kind; nothing is selected across a view change.
        final lastKind = last?.view?.kind;
        return (
          data: const AsyncLoading(),
          content: value == null || (lastKind != null && lastKind != view?.kind)
              ? null
              : _content(
                  value,
                  view: last?.view ?? view,
                  kind: last?.kind ?? kind,
                  preferences: last?.preferences ?? preferences,
                ),
          settled: null,
        );
    }
  }
}
