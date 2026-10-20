import 'dart:async';

import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/filters/search_index.dart';
import 'package:vikunja_mobile/core/repositories/saved_filter_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/repositories/task_search.dart';

import 'sync_fakes.dart';

/// Saved filter management as the real repository does it, on the saved
/// filters of [projects]: a success changes its `savedFilters`, definition
/// included, like the database would.
///
/// Every call is recorded in [calls] first: `create Title`,
/// `update -3 Title`, `delete -3`, `setFavorite -3 true`, `read -3`; the
/// drafts of creates and updates in [drafts]. [beforeCall] can hold one;
/// [failure], or the entry of [failures] for the method name (`create`, …),
/// is thrown instead while set, and nothing changes. Then the real
/// repository's checks: a blank title is an `ArgumentError`; a saved filter
/// [projects] does not list is a `NotFound` code 11001 for [update],
/// [setFavorite] and [read] (unless [online] has it), while [delete] counts
/// it as deleted.
final class FakeSavedFilterRepository implements SavedFilterRepository {
  new(this.projects);

  final FakeProjectRepository projects;
  final List<String> calls = [];
  final List<SavedFilterDraft> drafts = [];
  Exception? failure;
  final Map<String, Exception> failures = {};
  Future<void> Function(String call)? beforeCall;

  /// The id the next created saved filter gets; its pseudo project id is
  /// `-id - 1`.
  int nextFilterId = 700;

  /// What [read] answers for a saved filter, by pseudo project id, also
  /// when the listed one has no definition; it is stored then.
  final Map<int, SavedFilter> online = {};

  @override
  Future<int> create(SavedFilterDraft draft) async {
    drafts.add(draft);
    await _call('create', draft.title);
    final title = _checkedTitle(draft.title);
    final pseudoProjectId = SavedFilter.pseudoProjectIdOf(nextFilterId++);
    projects.savedFilters = [
      ...projects.savedFilters,
      _refOf(pseudoProjectId, draft, title),
    ];
    return pseudoProjectId;
  }

  @override
  Future<void> update(int pseudoProjectId, SavedFilterDraft draft) async {
    drafts.add(draft);
    await _call('update', '$pseudoProjectId ${draft.title}');
    final title = _checkedTitle(draft.title);
    _listed(pseudoProjectId);
    _replace(pseudoProjectId, (_) => _refOf(pseudoProjectId, draft, title));
  }

  @override
  Future<void> delete(int pseudoProjectId) async {
    await _call('delete', '$pseudoProjectId');
    projects.savedFilters = [
      for (final filter in projects.savedFilters)
        if (filter.projectId != pseudoProjectId) filter,
    ];
  }

  @override
  Future<void> setFavorite(
    int pseudoProjectId, {
    required bool favorite,
  }) async {
    await _call('setFavorite', '$pseudoProjectId $favorite');
    _listed(pseudoProjectId);
    _replace(
      pseudoProjectId,
      (filter) => SavedFilterRef(
        projectId: filter.projectId,
        title: filter.title,
        isFavorite: favorite,
        description: filter.description,
        updated: filter.updated,
        definition: filter.definition,
      ),
    );
  }

  @override
  Future<SavedFilter> read(int pseudoProjectId) async {
    await _call('read', '$pseudoProjectId');
    final filterId = SavedFilter.idOfPseudoProject(pseudoProjectId)!;
    if (online[pseudoProjectId] case final answer?) {
      _replace(
        pseudoProjectId,
        (filter) => SavedFilterRef(
          projectId: filter.projectId,
          title: answer.title,
          isFavorite: answer.isFavorite,
          description: answer.description,
          updated: filter.updated,
          definition: SavedFilterDefinition(
            filter: answer.filter,
            timezone: answer.timezone,
            updated: answer.updated,
          ),
        ),
      );
      return answer;
    }
    final listed = _listed(pseudoProjectId);
    final definition = listed.definition ?? (throw const NotFound(code: 11001));
    return SavedFilter(
      id: filterId,
      title: listed.title,
      description: listed.description,
      filter: definition.filter,
      isFavorite: listed.isFavorite,
      timezone: definition.timezone,
      updated: definition.updated,
    );
  }

  Future<void> _call(String method, String arguments) async {
    final call = '$method $arguments';
    calls.add(call);
    await beforeCall?.call(call);
    if (failures[method] ?? failure case final failure?) throw failure;
  }

  SavedFilterRef _listed(int pseudoProjectId) =>
      projects.savedFilters
          .where((filter) => filter.projectId == pseudoProjectId)
          .firstOrNull ??
      (throw const NotFound(code: 11001));

  void _replace(
    int pseudoProjectId,
    SavedFilterRef Function(SavedFilterRef filter) change,
  ) {
    projects.savedFilters = [
      for (final filter in projects.savedFilters)
        if (filter.projectId == pseudoProjectId) change(filter) else filter,
    ];
  }

  static SavedFilterRef _refOf(
    int pseudoProjectId,
    SavedFilterDraft draft,
    String title,
  ) => SavedFilterRef(
    projectId: pseudoProjectId,
    title: title,
    isFavorite: draft.isFavorite,
    description: draft.description,
    definition: SavedFilterDefinition(filter: draft.filter),
  );

  static String _checkedTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(title, 'title');
    return trimmed;
  }
}

/// The search over [tasks], [projects] (with its saved filters) and
/// [labels] as the real one does it ([SearchIndex]), again whenever one of
/// them changes; the archived projects are those of `tasks`'
/// `archivedProjectIds` plus the archived ones in `projects`.
///
/// Every query is recorded in [queries], every count in [counts] as
/// `(filter, projectId)`. A count answers [onCount] when set, else
/// [matchCount].
final class FakeTaskSearch implements TaskSearch {
  new({required this.tasks, required this.projects});

  final FakeTaskRepository tasks;
  final FakeProjectRepository projects;
  final List<String> queries = [];
  final List<(ViewFilter, int?)> counts = [];

  /// Null: the filter cannot be evaluated here.
  int? matchCount = 0;
  FutureOr<int?> Function(ViewFilter filter, int? projectId)? onCount;

  List<Label> get labels => _labels;

  set labels(List<Label> labels) {
    _labels = List.unmodifiable(labels);
    _labelChanges.add(null);
  }

  List<Label> _labels = const [];
  final _labelChanges = StreamController<void>.broadcast();

  /// While set and not completed, no query answers, as while the real
  /// search builds its index.
  Completer<void>? indexing;

  @override
  Stream<SearchResults> watch(String query) {
    queries.add(query);
    return Stream.multi((subscriber) {
      final ready = indexing?.future;
      void emit() {
        if (ready == null) {
          subscriber.add(resultsFor(query));
        } else {
          unawaited(ready.then((_) => subscriber.add(resultsFor(query))));
        }
      }

      final subscriptions = [
        tasks.watchSearchableTasks().listen((_) => emit()),
        projects.watchAll().skip(1).listen((_) => emit()),
        projects.watchSavedFilters().skip(1).listen((_) => emit()),
        _labelChanges.stream.listen((_) => emit()),
      ];
      subscriber.onCancel = () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      };
    });
  }

  SearchResults resultsFor(String query) {
    final found = SearchIndex.build(
      tasks: tasks.all,
      projects: projects.all,
      savedFilters: projects.savedFilters,
      labels: _labels,
      archivedProjectIds: {
        ...tasks.archivedProjectIds,
        for (final project in projects.all)
          if (project.isArchived) project.id,
      },
    ).search(query);
    return SearchResults(
      query: query,
      tasks: found.tasks.take(SearchResults.maxTasks).toList(),
      taskCount: found.tasks.length,
      projects: found.projects,
      savedFilters: found.savedFilters,
      labels: found.labels,
    );
  }

  @override
  Future<int?> countMatches(
    ViewFilter filter, {
    int? projectId,
    String timezone = '',
  }) async {
    counts.add((filter, projectId));
    if (onCount case final count?) return await count(filter, projectId);
    return matchCount;
  }
}
