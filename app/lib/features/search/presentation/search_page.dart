import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart' show TaskById;
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/repositories/task_search.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/list_note.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_row.dart';
import 'package:vikunja_mobile/features/search/application/search_providers.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/smart_list_row.dart';
import 'package:vikunja_mobile/features/sync/application/outbox_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/account_context_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/minimum_priority_provider.dart';
import 'package:vikunja_mobile/features/tasks/application/task_providers.dart'
    show taskByIdProvider;
import 'package:vikunja_mobile/features/tasks/presentation/open/task_opener.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_list_actions.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

/// One field over everything on this device: tasks (title, description,
/// `#12`, `PROJ-12`), projects, saved filters and labels, grouped in that
/// order and found as the user types, offline too. A task opens its sheet
/// over the search, a project or saved filter its list in the Projects
/// tab, a label the open tasks that have it. A pasted web address of a
/// task on the active account's server shows that task alone, or a row
/// that reads it from the server when this device does not have it.
class SearchPage extends ConsumerStatefulWidget {
  const new({super.key});

  /// How long typing pauses before the result count is announced.
  static const announceDelay = Duration(milliseconds: 800);

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage>
    with TaskListActions<SearchPage> {
  late final TextEditingController _query = _selectedAll(
    ref.read(lastSearchQueryProvider),
  );
  SearchResults? _lastResults;
  var _ready = false;
  Timer? _announce;
  String? _announcedQuery;
  String? _scheduledQuery;

  @override
  void dispose() {
    _announce?.cancel();
    _query.dispose();
    super.dispose();
  }

  /// The last query comes back selected, so typing replaces it.
  static TextEditingController _selectedAll(String text) =>
      TextEditingController.fromValue(
        TextEditingValue(
          text: text,
          selection: TextSelection(baseOffset: 0, extentOffset: text.length),
        ),
      );

  void _clear() {
    _query.clear();
    _queryChanged();
  }

  void _queryChanged() {
    ref.read(lastSearchQueryProvider.notifier).query = _query.text;
    setState(() {});
  }

  /// Once typing pauses, says how much [query] found, [count] results, as
  /// the web's live region does.
  void _announceWhenSettled(String query, int count) {
    if (query == _announcedQuery || query == _scheduledQuery) return;
    _scheduledQuery = query;
    _announce?.cancel();
    _announce = Timer(SearchPage.announceDelay, () {
      if (!mounted || query != _query.text.trim()) return;
      _announcedQuery = query;
      announce(context, context.l10n.searchResultCount(count));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = _query.text.trim();
    // Watched also without a query, which gets the search ready before the
    // first character.
    final searched = ref.watch(searchResultsProvider(query)).value;
    if (searched != null) _ready = true;
    final linked = ref.watch(activeLinkBasesProvider)?.pastedTaskLinkId(query);
    final found = query.isEmpty || linked != null ? null : searched;
    if (linked != null) _announceWhenSettled(query, 1);
    if (found != null) {
      _lastResults = found;
      _announceWhenSettled(
        found.query,
        found.taskCount +
            found.projects.length +
            found.savedFilters.length +
            found.labels.length,
      );
    }
    // While the next query's results come, the last ones stay.
    final results = query.isEmpty ? null : found ?? _lastResults;
    return Scaffold(
      appBar: AppBar(
        // The field is no heading; it still names the route on Android, as
        // an app bar's title does, by its label.
        excludeHeaderSemantics: true,
        title: Semantics(
          namesRoute: switch (Theme.of(context).platform) {
            TargetPlatform.iOS || TargetPlatform.macOS => null,
            _ => true,
          },
          label: l10n.search,
          child: TextField(
            controller: _query,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.searchHint,
              border: InputBorder.none,
            ),
            onChanged: (_) => _queryChanged(),
          ),
        ),
        actions: [
          if (_query.text.isNotEmpty)
            IconButton(
              onPressed: _clear,
              tooltip: l10n.clearSearch,
              icon: const Icon(Icons.close),
            ),
        ],
        bottom: _ready
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  semanticsLabel: l10n.searchPreparing,
                ),
              ),
      ),
      body: switch (results) {
        _ when linked != null => _LinkedTask(
          taskId: linked,
          onDoneChanged: (task, {required done}) =>
              unawaited(setTaskDone(task, done: done)),
          onFavoriteChanged: (task, {required favorite}) =>
              unawaited(setTaskFavorite(task, favorite: favorite)),
        ),
        null when query.isEmpty => CenteredScrollView(
          maxWidth: ReadableWidth.list,
          child: EmptyState(
            icon: Icons.search,
            title: l10n.searchStartTitle,
            body: l10n.searchStartBody,
          ),
        ),
        null => const SizedBox.shrink(),
        final results when results.isEmpty => CenteredScrollView(
          maxWidth: ReadableWidth.list,
          child: EmptyState(
            icon: Icons.search_off,
            title: l10n.searchNoResultsTitle,
            body: l10n.searchNoResultsBody(query),
          ),
        ),
        final results => _Results(
          results: results,
          tasks: withLeavingTasks(results.tasks),
          onDoneChanged: (task, {required done}) =>
              unawaited(setTaskDone(task, done: done)),
          onFavoriteChanged: (task, {required favorite}) =>
              unawaited(setTaskFavorite(task, favorite: favorite)),
        ),
      },
    );
  }
}

class _Results extends ConsumerWidget {
  const new({
    required this.results,
    required this.tasks,
    required this.onDoneChanged,
    required this.onFavoriteChanged,
  });

  final SearchResults results;

  /// [results]' tasks with those marked done here kept while their Undo
  /// shows.
  final List<Task> tasks;
  final _DoneChanged onDoneChanged;
  final _FavoriteChanged onFavoriteChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final taskRow = _taskRows(
      ref,
      onDoneChanged: onDoneChanged,
      onFavoriteChanged: onFavoriteChanged,
    );
    final router = GoRouter.of(context);
    final more = results.taskCount - results.tasks.length;
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverReadableWidth.group(
          maxWidth: ReadableWidth.list,
          slivers: [
            if (results.taskCount > 0) ...[
              SliverSectionCard(
                title: l10n.searchTasks,
                count: results.taskCount,
                itemCount: tasks.length,
                itemBuilder: (context, index) => taskRow(context, tasks[index]),
              ),
              if (more > 0)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: ListNote(
                      icon: Icons.more_horiz,
                      text: l10n.searchMoreTasks(more),
                    ),
                  ),
                ),
            ],
            if (results.projects.isNotEmpty) ...[
              SliverSectionCard(
                title: l10n.searchProjects,
                count: results.projects.length,
                itemCount: results.projects.length,
                itemBuilder: (context, index) {
                  final project = results.projects[index];
                  return ProjectRow(
                    key: ValueKey(('project', project.id)),
                    project: project,
                    onTap: () => router.go(AppRoutes.project(project.id)),
                  );
                },
              ),
            ],
            if (results.savedFilters.isNotEmpty) ...[
              SliverSectionCard(
                title: l10n.savedFiltersHeading,
                count: results.savedFilters.length,
                itemCount: results.savedFilters.length,
                itemBuilder: (context, index) {
                  final filter = results.savedFilters[index];
                  return _SavedFilterResult(
                    key: ValueKey(('filter', filter.projectId)),
                    filter: filter,
                    onTap: () => router.go(AppRoutes.project(filter.projectId)),
                  );
                },
              ),
            ],
            if (results.labels.isNotEmpty) ...[
              SliverSectionCard(
                title: l10n.searchLabels,
                count: results.labels.length,
                itemCount: results.labels.length,
                itemBuilder: (context, index) {
                  final label = results.labels[index];
                  return _LabelResult(
                    key: ValueKey(('label', label.id)),
                    label: label,
                    onTap: () =>
                        unawaited(router.push(AppRoutes.labelTasks(label.id))),
                  );
                },
              ),
            ],
            const SliverSafeArea(
              top: false,
              sliver: SliverToBoxAdapter(child: SizedBox(height: 16)),
            ),
          ],
        ),
      ],
    );
  }
}

typedef _DoneChanged = void Function(Task task, {required bool done});
typedef _FavoriteChanged = void Function(Task task, {required bool favorite});

/// The search's task rows, with what they show watched on [ref]: a tap
/// opens the task's sheet over the search.
Widget Function(BuildContext context, Task task) _taskRows(
  WidgetRef ref, {
  required _DoneChanged onDoneChanged,
  required _FavoriteChanged onFavoriteChanged,
}) {
  final projects = ref.watch(projectsProvider).value ?? const <Project>[];
  final projectsById = {for (final project in projects) project.id: project};
  final now = ref.watch(clockTickProvider);
  final minimumPriority = ref.watch(minimumPriorityProvider);
  final pendingIds =
      ref.watch(pendingTaskIdsProvider).unwrapPrevious().value ?? const {};
  return (context, task) {
    final project = projectsById[task.projectId];
    // A favourite task of an archived project is found too; the server
    // refuses changes to it.
    final archived = isArchivedInTree(task.projectId, projectsById);
    return TaskRow(
      key: ValueKey(('task', task.id)),
      task: task,
      now: now,
      minimumPriority: minimumPriority,
      projectTitle: project?.displayTitle(context.l10n),
      projectHexColor: project?.hexColor,
      pending: pendingIds.contains(task.id),
      onTap: () => unawaited(showTaskDetail(context, task: task)),
      onDoneChanged: archived
          ? null
          : (done) => onDoneChanged(task, done: done),
      onFavoriteChanged: archived
          ? null
          : (favorite) => onFavoriteChanged(task, favorite: favorite),
    );
  };
}

/// The task a pasted link names: its row when this device has it, else a
/// row that reads it from the server and opens it.
class _LinkedTask extends ConsumerWidget {
  const new({
    required this.taskId,
    required this.onDoneChanged,
    required this.onFavoriteChanged,
  });

  final int taskId;
  final _DoneChanged onDoneChanged;
  final _FavoriteChanged onFavoriteChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final task = ref.watch(taskByIdProvider(taskId)).value;
    final taskRow = _taskRows(
      ref,
      onDoneChanged: onDoneChanged,
      onFavoriteChanged: onFavoriteChanged,
    );
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverReadableWidth.group(
          maxWidth: ReadableWidth.list,
          slivers: [
            SliverSectionCard(
              title: l10n.searchLinkedTask,
              itemCount: 1,
              itemBuilder: (context, _) => task == null
                  ? ListTile(
                      key: ValueKey(('linked', taskId)),
                      leading: const Icon(Icons.link),
                      title: Text(l10n.searchOpenLinkedTask),
                      onTap: () => unawaited(
                        ref
                            .read(taskOpenerProvider)
                            .openInActiveAccount(TaskById(taskId)),
                      ),
                    )
                  : taskRow(context, task),
            ),
            const SliverSafeArea(
              top: false,
              sliver: SliverToBoxAdapter(child: SizedBox(height: 16)),
            ),
          ],
        ),
      ],
    );
  }
}

class _SavedFilterResult extends StatelessWidget {
  const new({required this.filter, required this.onTap, super.key});

  final SavedFilterRef filter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SmartListRow(
    icon: Icons.filter_list,
    title: projectDisplayTitle(
      context.l10n,
      filter.title,
      projectId: filter.projectId,
    ),
    favorite: filter.isFavorite,
    onTap: onTap,
  );
}

class _LabelResult extends StatelessWidget {
  const new({required this.label, required this.onTap, super.key});

  final Label label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = parseHexColor(label.hexColor);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 8),
      leading: ExcludeSemantics(
        child: color == null
            ? Icon(Icons.label_outline, color: colors.onSurfaceVariant)
            : DecoratedBox(
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const SizedBox.square(dimension: 16),
              ),
      ),
      title: Text(label.title),
    );
  }
}
