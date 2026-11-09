import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/text/html_to_text.dart';
import 'package:vikunja_mobile/core/text/title_order.dart';

/// [text] for a comparison that ignores case and accents, so that "cafe"
/// finds "Café" on every server, as Vikunja 2.8.0 searches on PostgreSQL
/// with unaccent: lower case, plus the full case foldings lower-casing
/// leaves out (`ß` and `ss`, `ς` and `σ`, the Latin ligatures), then
/// [foldAccents].
String foldForSearch(String text) {
  final lower = text.toLowerCase();
  return foldAccents(
    lower.contains(_beyondLowerCase)
        ? lower.replaceAllMapped(
            _beyondLowerCase,
            (match) => _fullFoldings[match[0]]!,
          )
        : lower,
  );
}

const _fullFoldings = {
  'ß': 'ss',
  'ẞ': 'ss',
  'ς': 'σ',
  'ſ': 's',
  'ﬀ': 'ff',
  'ﬁ': 'fi',
  'ﬂ': 'fl',
  'ﬃ': 'ffi',
  'ﬄ': 'ffl',
  'ﬅ': 'st',
  'ﬆ': 'st',
};

final _beyondLowerCase = RegExp('[ßẞςſﬀ-ﬆ]');

/// A query of the search page, parsed once: the folded text, the index of a
/// `#12` in it, and the identifier and index when the whole query is one
/// like `PROJ-12`.
final class SearchQuery {
  factory parse(String query) {
    final trimmed = query.trim();
    final index = switch (_hashIndex.firstMatch(trimmed)) {
      final match? => int.tryParse(match[1]!),
      null => null,
    };
    final reference = _reference.firstMatch(trimmed);
    return SearchQuery._(
      folded: foldForSearch(trimmed),
      index: index != null && index > 0 ? index : null,
      identifier: reference == null ? null : foldForSearch(reference[1]!),
      identifierIndex: reference == null ? null : int.tryParse(reference[2]!),
    );
  }

  const new _({
    required this.folded,
    required this.index,
    required this.identifier,
    required this.identifierIndex,
  });

  static final _hashIndex = RegExp(r'#(\d+)');
  static final _reference = RegExp(r'^(\S+)-(\d+)$');

  final String folded;
  final int? index;
  final String? identifier;
  final int? identifierIndex;

  bool get isEmpty => folded.isEmpty;

  bool matchesText(String foldedText) => foldedText.contains(folded);
}

/// One task as the search compares it.
final class _SearchableTask {
  new(this.task, {required String projectIdentifier, _SearchableTask? before})
    : title = before?.task.title == task.title
          ? before!.title
          : foldForSearch(task.title),
      description = before?.task.description == task.description
          ? before!.description
          : task.description.isEmpty
          ? ''
          : foldForSearch(htmlToPlainText(task.description)),
      projectIdentifier = foldForSearch(projectIdentifier);

  final Task task;
  final String title;
  final String description;
  final String projectIdentifier;

  bool reusedFrom(_SearchableTask? before) =>
      before != null &&
      identical(title, before.title) &&
      identical(description, before.description);

  bool matches(SearchQuery query) =>
      query.matchesText(title) ||
      query.matchesText(description) ||
      (query.index != null && task.index == query.index) ||
      (query.identifier != null &&
          projectIdentifier.isNotEmpty &&
          projectIdentifier == query.identifier &&
          task.index == query.identifierIndex);
}

/// The local data the search page looks through, folded once per change
/// of it: [search] then only compares.
final class SearchIndex {
  /// [projects] are every stored project: those archived (themselves or
  /// above) are left out, and so are their tasks unless favourite. A task
  /// whose title and description are those it had in [previous] keeps
  /// their folded text instead of converting its description again.
  factory build({
    required Iterable<Task> tasks,
    required Iterable<Project> projects,
    required Set<int> archivedProjectIds,
    Iterable<SavedFilterRef> savedFilters = const [],
    Iterable<Label> labels = const [],
    SearchIndex? previous,
  }) {
    final identifiers = {
      for (final project in projects) project.id: project.identifier,
    };
    final before = {
      for (final entry in previous?._tasks ?? const <_SearchableTask>[])
        entry.task.id: entry,
    };
    final searchable = [
      for (final task in tasks)
        if (task.isFavorite || !archivedProjectIds.contains(task.projectId))
          _SearchableTask(
            task,
            projectIdentifier: identifiers[task.projectId] ?? '',
            before: before[task.id],
          ),
    ];
    return SearchIndex._(
      tasks: searchable,
      foldedTasks: searchable
          .where((entry) => !entry.reusedFrom(before[entry.task.id]))
          .length,
      projects: [
        for (final project in projects)
          if (!project.isPseudo && !archivedProjectIds.contains(project.id))
            (
              project,
              foldForSearch(project.title),
              foldForSearch(htmlToPlainText(project.description)),
            ),
      ],
      // The web edits these descriptions as rich text too.
      savedFilters: [
        for (final filter in savedFilters)
          (
            filter,
            foldForSearch(filter.title),
            foldForSearch(htmlToPlainText(filter.description)),
          ),
      ],
      labels: [
        for (final label in labels)
          (
            label,
            foldForSearch(label.title),
            foldForSearch(htmlToPlainText(label.description)),
          ),
      ],
    );
  }

  const new _({
    required this._tasks,
    required this.foldedTasks,
    required this._projects,
    required this._savedFilters,
    required this._labels,
  });

  /// How many tasks this index folded itself, the rest coming from the
  /// previous one.
  @visibleForTesting
  final int foldedTasks;

  final List<_SearchableTask> _tasks;
  final List<(Project, String, String)> _projects;
  final List<(SavedFilterRef, String, String)> _savedFilters;
  final List<(Label, String, String)> _labels;

  /// The matching tasks in the results' order (open first, then nearest
  /// due date, none last, then newest first) and the rest in theirs; an
  /// empty query finds nothing.
  ({
    List<Task> tasks,
    List<Project> projects,
    List<SavedFilterRef> savedFilters,
    List<Label> labels,
  })
  search(String query) {
    final parsed = SearchQuery.parse(query);
    if (parsed.isEmpty) {
      return (
        tasks: const [],
        projects: const [],
        savedFilters: const [],
        labels: const [],
      );
    }
    bool matches((Object, String, String) entry) =>
        parsed.matchesText(entry.$2) || parsed.matchesText(entry.$3);
    return (
      tasks: [
        for (final entry in _tasks)
          if (entry.matches(parsed)) entry.task,
      ]..sort(compareSearchedTasks),
      projects: [
        for (final entry in _projects)
          if (matches(entry)) entry.$1,
      ]..sort((a, b) => _byTitle(a.title, b.title, a.id, b.id)),
      savedFilters: [
        for (final entry in _savedFilters)
          if (matches(entry)) entry.$1,
      ]..sort((a, b) => _byTitle(a.title, b.title, a.projectId, b.projectId)),
      labels: [
        for (final entry in _labels)
          if (matches(entry)) entry.$1,
      ]..sort((a, b) => _byTitle(a.title, b.title, a.id, b.id)),
    );
  }

  static int _byTitle(String a, String b, int idA, int idB) {
    final byTitle = compareTitles(a, b);
    return byTitle != 0 ? byTitle : idA.compareTo(idB);
  }
}

/// Open before done, then nearest due date first (none last), then newest
/// first, a task created here before every server task.
int compareSearchedTasks(Task a, Task b) {
  if (a.done != b.done) return a.done ? 1 : -1;
  final byDue = switch ((a.dueDate, b.dueDate)) {
    (null, null) => 0,
    (null, _) => 1,
    (_, null) => -1,
    (final a?, final b?) => a.compareTo(b),
  };
  if (byDue != 0) return byDue;
  if ((a.id < 0) != (b.id < 0)) return a.id < 0 ? -1 : 1;
  return b.id.abs().compareTo(a.id.abs());
}
