import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/features/projects/application/project_list_model.dart';
import 'package:vikunja_mobile/features/projects/application/table_model.dart';

/// The rows of a project's list or table view, worked out again only when
/// what they are built from changed: the source (by identity), the view's
/// filter kind, the sort, the done toggle, and the copies kept while an
/// Undo is offered (by content). The project screen builds again on every
/// selection tap, the minute's clock tick and every queued change, none of
/// which changes them, and sorting and nesting a large project's tasks
/// each time would cost frames.
final class ProjectRows {
  ({
    ProjectListSource source,
    ViewFilterKind kind,
    ViewPreferences preferences,
    Map<int, Task> leaving,
    ProjectListModel model,
  })?
  _list;

  ({
    ProjectListSource source,
    ViewFilterKind kind,
    bool showDone,
    TableSort sort,
    Map<int, Task> leaving,
    List<Task> rows,
  })?
  _table;

  /// [buildProjectListModel]'s model.
  ProjectListModel listModel(
    ProjectListSource source, {
    required ViewFilterKind kind,
    required ViewPreferences preferences,
    Map<int, Task> leaving = const {},
  }) {
    if (_list case final last?
        when identical(last.source, source) &&
            last.kind == kind &&
            last.preferences == preferences &&
            mapEquals(last.leaving, leaving)) {
      return last.model;
    }
    final model = buildProjectListModel(
      source,
      kind: kind,
      preferences: preferences,
      leaving: leaving,
    );
    _list = (
      source: source,
      kind: kind,
      preferences: preferences,
      leaving: leaving,
      model: model,
    );
    return model;
  }

  /// [buildTableRows]' rows in [sort]'s order.
  List<Task> tableRows(
    ProjectListSource source, {
    required ViewFilterKind kind,
    required bool showDone,
    required TableSort sort,
    Map<int, Task> leaving = const {},
  }) {
    if (_table case final last?
        when identical(last.source, source) &&
            last.kind == kind &&
            last.showDone == showDone &&
            last.sort == sort &&
            mapEquals(last.leaving, leaving)) {
      return last.rows;
    }
    final rows = buildTableRows(
      source,
      kind: kind,
      showDone: showDone,
      compare: (a, b) => compareTasksForTable(a, b, sort),
      leaving: leaving,
    );
    _table = (
      source: source,
      kind: kind,
      showDone: showDone,
      sort: sort,
      leaving: leaving,
      rows: rows,
    );
    return rows;
  }
}
