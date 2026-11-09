import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/widgets/status_card.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/trash_repository.dart';
import 'package:vikunja_mobile/core/repositories/trash_repository_providers.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/sync/application/page_reachability.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_notice.dart';
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';
import 'package:vikunja_mobile/features/trash/presentation/trash_failure_text.dart';
import 'package:vikunja_mobile/features/trash/presentation/trash_rows.dart';

final _log = Logger('Trash');

/// The server's trash, "the bin" (Vikunja 2.8.0 and later), in two tabs:
/// the deleted tasks of the projects the user may write to, and the
/// deleted projects the user is admin of. Both are read from the server
/// each time the page opens and on pull to refresh (the bin is not
/// stored). Each item can be restored or deleted forever, and each tab
/// emptied; one action at a time.
class TrashPage extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<TrashPage> createState() => _TrashPageState();
}

/// One tab's list and its reads.
final class _Listing<T> {
  new(this.read);

  final Future<List<T>> Function(TrashRepository trash) read;
  List<T>? items;
  Object? failure;
  bool loading = false;
  int loads = 0;
}

class _TrashPageState extends ConsumerState<TrashPage> with PageReachability {
  final _tasks = _Listing<TrashedTask>((trash) => trash.tasks());
  final _projects = _Listing<TrashedProject>((trash) => trash.projects());

  /// The action on its way: `task <id>`, `project <id>`, `empty tasks` or
  /// `empty projects`, and `asking` while Empty bin's question is open.
  String? _busy;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    await Future.wait([_load(_tasks), _load(_projects)]);
  }

  /// The latest read of [list] wins: one that started earlier may still
  /// hold an item that an action has taken out since.
  Future<void> _load<T>(_Listing<T> list) async {
    final trash = ref.read(trashRepositoryProvider);
    if (trash == null) return;
    final load = ++list.loads;
    setState(() => list.loading = true);
    bool latest() => mounted && load == list.loads;
    try {
      final items = await list.read(trash);
      if (latest()) {
        setState(() {
          list
            ..items = items
            ..failure = null;
          noteReached();
        });
      }
    } on Object catch (error) {
      _log.info('Reading the bin failed: ${error.runtimeType}');
      if (latest()) {
        setState(() {
          list.failure = error;
          noteFailure(error);
        });
      }
    } finally {
      if (latest()) setState(() => list.loading = false);
    }
  }

  /// Runs [send] as the page's one action, under [busy]. Then [apply]
  /// changes [list] and [done] is said; a failure is said in a snackbar,
  /// and a `NotFound` with a code reads [list] again: the item is no longer
  /// where the page shows it. True when it went through.
  Future<bool> _act<T>(
    String busy,
    TrashAction action, {
    required _Listing<T> list,
    required Future<void> Function() send,
    required List<T> Function(List<T> items) apply,
    required String done,
  }) async {
    final l10n = context.l10n;
    final announcer = Announcer.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = busy);
    try {
      await send();
      if (!mounted) return true;
      setState(() {
        if (list.items case final items?) list.items = apply(items);
        noteReached();
      });
      unawaited(HapticFeedback.selectionClick());
      announcer.say(done);
      if (list.loading) unawaited(_load(list));
      return true;
    } on Object catch (error) {
      _log.info('A bin action failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(trashFailureText(l10n, error, action))),
        );
      if (mounted) {
        setState(() => noteFailure(error));
        if (error case NotFound(routeAbsent: false)) unawaited(_load(list));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _restoreTask(TrashedTask item) async {
    final tasks = ref.read(taskRepositoryProvider);
    if (tasks == null || _busy != null) return;
    final id = item.task.id;
    await _act(
      'task $id',
      TrashAction.restoreTask,
      list: _tasks,
      send: () => tasks.restoreTask(id),
      apply: (items) => _withoutTask(items, id),
      done: context.l10n.taskRestored,
    );
  }

  /// The tasks the user deleted on their own in the project come back
  /// with it, so the Tasks tab is read again.
  Future<void> _restoreProject(TrashedProject item) async {
    final projects = ref.read(projectRepositoryProvider);
    if (projects == null || _busy != null) return;
    final id = item.project.id;
    final restored = await _act(
      'project $id',
      TrashAction.restoreProject,
      list: _projects,
      send: () => projects.restoreProject(id),
      apply: (items) => _withoutProject(items, id),
      done: context.l10n.projectRestored,
    );
    if (restored && mounted) unawaited(_load(_tasks));
  }

  Future<void> _deleteTaskForever(TrashedTask item) async {
    final trash = ref.read(trashRepositoryProvider);
    if (trash == null || _busy != null) return;
    final l10n = context.l10n;
    final confirmed = await confirmAdaptive(
      context,
      title: l10n.trashDeleteForeverTitle(trashItemTitle(item.task.title)),
      body: l10n.trashDeleteTaskForeverBody,
      confirmLabel: l10n.trashDeleteForever,
      destructive: true,
    );
    if (!confirmed || !mounted || _busy != null) return;
    final id = item.task.id;
    await _act(
      'task $id',
      TrashAction.deleteTaskForever,
      list: _tasks,
      send: () => trash.deleteTaskForever(id),
      apply: (items) => _withoutTask(items, id),
      done: l10n.trashTaskDeletedForever,
    );
  }

  Future<void> _deleteProjectForever(TrashedProject item) async {
    final trash = ref.read(trashRepositoryProvider);
    if (trash == null || _busy != null) return;
    final l10n = context.l10n;
    final confirmed = await confirmAdaptive(
      context,
      title: l10n.trashDeleteForeverTitle(
        trashItemTitle(item.project.displayTitle(l10n)),
      ),
      body: l10n.trashDeleteProjectForeverBody,
      confirmLabel: l10n.trashDeleteForever,
      destructive: true,
    );
    if (!confirmed || !mounted || _busy != null) return;
    final id = item.project.id;
    await _act(
      'project $id',
      TrashAction.deleteProjectForever,
      list: _projects,
      send: () => trash.deleteProjectForever(id),
      apply: (items) => _withoutProject(items, id),
      done: l10n.trashProjectDeletedForever,
    );
  }

  /// Asks the server how many it would delete first: a user who is admin
  /// of none of the projects can delete nothing. When it would delete none,
  /// or the empty itself fails on the way or at the server, the tab is read
  /// again: the list may be out of date, or the server may have emptied it.
  Future<void> _empty({required bool tasks}) async {
    final trash = ref.read(trashRepositoryProvider);
    if (trash == null || _busy != null) return;
    final l10n = context.l10n;
    final announcer = Announcer.of(context);
    final messenger = ScaffoldMessenger.of(context);
    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
    void readAgain() => unawaited(tasks ? _load(_tasks) : _load(_projects));
    final busy = tasks ? 'empty tasks' : 'empty projects';
    setState(() => _busy = busy);
    var sent = false;
    try {
      final count = await (tasks ? trash.taskCount() : trash.projectCount());
      if (!mounted) return;
      final keepsOthers =
          tasks &&
          (_tasks.items ?? const <TrashedTask>[]).any(
            (item) => !item.canDeletePermanently,
          );
      if (count.total == 0) {
        if (keepsOthers) say(l10n.trashEmptyNothing);
        readAgain();
        return;
      }
      setState(() => _busy = 'asking');
      final confirmed = await confirmAdaptive(
        context,
        title: tasks ? l10n.trashEmptyTasksTitle : l10n.trashEmptyProjectsTitle,
        body: [
          if (tasks)
            l10n.trashEmptyTasks(count.total)
          else
            l10n.trashEmptyProjects(count.total),
          if (count.byOthers > 0) l10n.trashEmptyByOthers(count.byOthers),
          if (keepsOthers) l10n.trashEmptyKeepsOthers,
          l10n.trashCannotBeUndone,
        ].join('\n\n'),
        confirmLabel: l10n.trashDeleteForever,
        destructive: true,
      );
      if (!confirmed || !mounted) return;
      setState(() => _busy = busy);
      sent = true;
      await (tasks ? trash.emptyTasks() : trash.emptyProjects());
      if (!mounted) return;
      // What the server deleted goes at once; the read after says what
      // stayed.
      setState(() {
        if (tasks) {
          if (_tasks.items case final items?) {
            _tasks.items = [
              for (final item in items)
                if (!item.canDeletePermanently) item,
            ];
          }
        } else if (_projects.items != null) {
          _projects.items = const [];
        }
        noteReached();
      });
      unawaited(HapticFeedback.selectionClick());
      announcer.say(l10n.trashEmptied);
      readAgain();
    } on Object catch (error) {
      _log.info('Emptying the bin failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      say(trashFailureText(l10n, error, TrashAction.empty));
      if (mounted) {
        setState(() => noteFailure(error));
        if (sent && (error is NetworkFailure || error is ServerFailure)) {
          readAgain();
        }
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  static List<TrashedTask> _withoutTask(List<TrashedTask> items, int id) => [
    for (final item in items)
      if (item.task.id != id) item,
  ];

  static List<TrashedProject> _withoutProject(
    List<TrashedProject> items,
    int id,
  ) => [
    for (final item in items)
      if (item.project.id != id) item,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final offline = watchOffline(
      onBackOnline: () {
        if (_tasks.failure is NetworkFailure) unawaited(_load(_tasks));
        if (_projects.failure is NetworkFailure) unawaited(_load(_projects));
      },
    );
    final projects = {
      for (final project in ref.watch(projectsProvider).value ?? <Project>[])
        project.id: project,
    };
    final busy = _busy;
    final tasks = _tasks.items;
    final trashedProjects = _projects.items;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: ScreenTitle(l10n.trashTitle),
          actions: [
            RefreshButton(
              onPressed: _tasks.loading || _projects.loading
                  ? null
                  : () => unawaited(_reload()),
            ),
          ],
          bottom: _TrashTabBar(
            label: l10n.trashTabsLabel,
            titles: [l10n.trashTasksTab, l10n.trashProjectsTab],
          ),
        ),
        body: TabBarView(
          children: [
            _TrashTab(
              storageKey: const PageStorageKey('trash tasks'),
              listing: _tasks,
              offline: offline,
              emptyTitle: l10n.trashTasksEmptyTitle,
              emptyBody: l10n.trashTasksEmptyBody,
              emptying: busy == 'empty tasks',
              onEmpty: busy == null
                  ? () => unawaited(_empty(tasks: true))
                  : null,
              onRefresh: _reload,
              onRetry: () => unawaited(_load(_tasks)),
              itemBuilder: (context, index) {
                final item = tasks![index];
                return TrashTaskRow(
                  key: ValueKey(item.task.id),
                  item: item,
                  project: projects[item.task.projectId],
                  busy: busy == 'task ${item.task.id}',
                  enabled: busy == null,
                  onRestore: () => unawaited(_restoreTask(item)),
                  onDeleteForever: () => unawaited(_deleteTaskForever(item)),
                );
              },
            ),
            _TrashTab(
              storageKey: const PageStorageKey('trash projects'),
              listing: _projects,
              offline: offline,
              emptyTitle: l10n.trashProjectsEmptyTitle,
              emptyBody: l10n.trashProjectsEmptyBody,
              emptying: busy == 'empty projects',
              onEmpty: busy == null
                  ? () => unawaited(_empty(tasks: false))
                  : null,
              onRefresh: _reload,
              onRetry: () => unawaited(_load(_projects)),
              itemBuilder: (context, index) {
                final item = trashedProjects![index];
                return TrashProjectRow(
                  key: ValueKey(item.project.id),
                  item: item,
                  busy: busy == 'project ${item.project.id}',
                  enabled: busy == null,
                  onRestore: () => unawaited(_restoreProject(item)),
                  onDeleteForever: () => unawaited(_deleteProjectForever(item)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The tabs, where the rows are on a large window, below a divider across
/// the app bar; they scroll sideways when a title would not fit its half,
/// e.g. at large text.
class _TrashTabBar extends StatelessWidget implements PreferredSizeWidget {
  const new({required this.label, required this.titles});

  final String label;
  final List<String> titles;

  @override
  Size get preferredSize => const Size.fromHeight(kTextTabBarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.tabBarTheme.labelStyle ?? theme.textTheme.titleSmall;
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double widthOf(String title) {
      final painter = TextPainter(
        text: TextSpan(text: title, style: style),
        textScaler: textScaler,
        textDirection: direction,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final widest = titles.map(widthOf).fold<double>(0, math.max);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: ReadableWidth(
        maxWidth: ReadableWidth.list,
        child: Semantics(
          container: true,
          label: label,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scrolls =
                  widest + kTabLabelPadding.horizontal >
                  constraints.maxWidth / titles.length;
              return TabBar(
                isScrollable: scrolls,
                tabAlignment: scrolls ? TabAlignment.start : TabAlignment.fill,
                dividerColor: Colors.transparent,
                tabs: [for (final title in titles) Tab(text: title)],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One tab: its notice, the first read's failure, loading, the empty state,
/// or the retention note with Empty bin above the rows. Built lazily: the
/// bin can hold up to a thousand items.
class _TrashTab extends StatelessWidget {
  const new({
    required this.storageKey,
    required this.listing,
    required this.offline,
    required this.emptyTitle,
    required this.emptyBody,
    required this.emptying,
    required this.onEmpty,
    required this.onRefresh,
    required this.onRetry,
    required this.itemBuilder,
  });

  /// Keeps the tab's scroll offset while the other tab shows.
  final PageStorageKey<String> storageKey;
  final _Listing<Object?> listing;
  final bool offline;
  final String emptyTitle;
  final String emptyBody;

  /// The tab's Empty bin is on its way; [onEmpty] is null then too.
  final bool emptying;

  /// Null while any action of the page is on its way.
  final VoidCallback? onEmpty;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = listing.items;
    final failure = listing.failure;
    final notice = switch (failure) {
      NetworkFailure(
        problem: NetworkProblem(concernsConnectionSettings: false),
      ) =>
        const OfflineNotice(),
      final failure? when items != null => _FailureCard(
        error: failure,
        stale: true,
        onRetry: onRetry,
      ),
      null when offline => const OfflineNotice(),
      _ => null,
    };

    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      child: ReadableWidth.builder(
        maxWidth: ReadableWidth.list,
        builder: (_, _, inset) => CustomScrollView(
          key: storageKey,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding:
                  MediaQuery.paddingOf(context) +
                  EdgeInsets.fromLTRB(inset, 8, inset, 16),
              sliver: SliverMainAxisGroup(
                slivers: [
                  if (notice != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: notice,
                      ),
                    ),
                  if (items == null && failure != null && notice == null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _FailureCard(
                          error: failure,
                          stale: false,
                          onRetry: onRetry,
                        ),
                      ),
                    )
                  else if (items == null && listing.loading)
                    SliverToBoxAdapter(
                      child: LoadingPlaceholder(label: l10n.trashLoading),
                    )
                  else if (items != null && items.isEmpty)
                    SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.delete_outline,
                        title: emptyTitle,
                        body: emptyBody,
                      ),
                    )
                  else if (items != null) ...[
                    SliverToBoxAdapter(
                      child: _EmptyBinHeader(
                        emptying: emptying,
                        onEmpty: onEmpty,
                      ),
                    ),
                    SliverSectionCard(
                      itemCount: items.length,
                      itemBuilder: itemBuilder,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A failed read, as [DataFailureCard] explains it, except on a server
/// without the bin: there "This server has no bin", with no retry. A bare
/// 404 from a server that has the bin (a proxy during a deploy) keeps the
/// retry.
class _FailureCard extends ConsumerWidget {
  const new({required this.error, required this.stale, required this.onRetry});

  final Object error;
  final bool stale;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (error case NotFound(routeAbsent: true)
        when !ref.watch(activeServerHasTrashProvider)) {
      final l10n = context.l10n;
      final colors = Theme.of(context).colorScheme;
      return StatusCard(
        icon: Icons.error_outline,
        title: stale ? l10n.dataFailureRefreshTitle : l10n.dataFailureLoadTitle,
        body: l10n.trashUnavailable,
        footnote: stale ? l10n.dataFailureStaleNote : null,
        background: colors.errorContainer,
        foreground: colors.onErrorContainer,
        liveRegion: true,
      );
    }
    return DataFailureCard(error: error, stale: stale, onRetry: onRetry);
  }
}

/// How long the bin keeps what is in it, and Empty bin.
class _EmptyBinHeader extends StatelessWidget {
  const new({required this.emptying, required this.onEmpty});

  final bool emptying;
  final VoidCallback? onEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.trashRetentionNote,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: onEmpty,
              style: TextButton.styleFrom(foregroundColor: colors.error),
              icon: emptying
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: l10n.trashWorking,
                      ),
                    )
                  : const Icon(Icons.delete_sweep_outlined),
              label: Text(l10n.trashEmpty),
            ),
          ),
        ],
      ),
    );
  }
}
