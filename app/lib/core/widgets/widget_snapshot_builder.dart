import 'package:flutter/foundation.dart' show immutable;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/account_title.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/filters/local_filters.dart';
import 'package:vikunja_mobile/core/links/widget_link.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/local/local_list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/archived_projects.dart';
import 'package:vikunja_mobile/core/sync/saved_filters.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/core/text/title_order.dart';
import 'package:vikunja_mobile/core/widgets/widget_catalog.dart';
import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/core/widgets/widget_snapshot.dart';
import 'package:vikunja_mobile/core/widgets/widget_texts.dart';
import 'package:vikunja_mobile/features/overview/application/due_date_groups.dart';
import 'package:vikunja_mobile/features/projects/application/project_access.dart';
import 'package:vikunja_mobile/features/projects/application/project_list_model.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';
import 'package:vikunja_mobile/features/tasks/application/default_project.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_meta.dart';

/// The account a build is for, as the registry knows it.
@immutable
final class WidgetAccount {
  const new({
    required this.id,
    required this.title,
    required this.host,
    required this.isGuest,
    required this.sessionEnded,
    required this.supportsV2,
    this.showsAccount = false,
  });

  /// [showsAccount] while more than one account is signed in.
  factory of(RegisteredAccount entry, {required bool showsAccount}) =>
      WidgetAccount(
        id: entry.id,
        title: accountTitle(entry.account),
        host: entry.account.serverRoot.host,
        isGuest: entry.account.isLinkShare,
        sessionEnded: entry.account.needsReauth,
        supportsV2: entry.connection.apiVersions.contains(ApiVersion.v2),
        showsAccount: showsAccount,
      );

  final String id;
  final String title;
  final String host;
  final bool isGuest;
  final bool sessionEnded;
  final bool supportsV2;
  final bool showsAccount;

  WidgetSnapshotState get state => switch ((sessionEnded, isGuest)) {
    (false, _) => WidgetSnapshotState.ok,
    (true, false) => WidgetSnapshotState.needsReauth,
    (true, true) => WidgetSnapshotState.guestEnded,
  };

  @override
  bool operator ==(Object other) =>
      other is WidgetAccount &&
      other.id == id &&
      other.title == title &&
      other.host == host &&
      other.isGuest == isGuest &&
      other.sessionEnded == sessionEnded &&
      other.supportsV2 == supportsV2 &&
      other.showsAccount == showsAccount;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    host,
    isGuest,
    sessionEnded,
    supportsV2,
    showsAccount,
  );
}

/// `showsTaskTitles` as the device's privacy setting was when built.
typedef WidgetBuild = ({
  Map<String, WidgetSnapshot> snapshots,
  WidgetCatalog? catalog,
  bool showsTaskTitles,
});

/// The widgets' content of one account, from its database at one instant,
/// with the account's own display settings: the same sources, order,
/// permissions and texts as the app's screens. Headless: nothing here
/// needs a widget tree. Without `showTaskTitles` (a device privacy
/// setting) a list carries its title and count but no rows, so no task
/// title and no Done reach the home screen.
final class WidgetSnapshotBuilder {
  new({
    required this._db,
    required this._texts,
    this._showTaskTitles = true,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final WidgetTexts _texts;
  final bool _showTaskTitles;
  final DateTime Function() _now;

  /// The snapshots of [kinds] by key, and the account's catalog when
  /// [withCatalog]; the database is read once for all of them.
  Future<WidgetBuild> build(
    WidgetAccount account,
    Iterable<WidgetKind> kinds, {
    bool withCatalog = true,
  }) async {
    final build = await _AccountBuild.load(
      _db,
      _texts,
      account,
      _now(),
      showTaskTitles: _showTaskTitles,
    );
    return (
      snapshots: {
        for (final kind in kinds.toSet())
          snapshotKey(account.id, kind): await build.snapshot(kind),
      },
      catalog: withCatalog ? build.catalog() : null,
      showsTaskTitles: _showTaskTitles,
    );
  }
}

/// What a widget of a signed-out or removed account shows until it is set
/// up again; no row, no title of the account's.
WidgetSnapshot removedAccountSnapshot(
  String key, {
  required String accountId,
  required AppLocalizations l10n,
  required DateTime now,
}) => WidgetSnapshot(
  key: key,
  accountId: accountId,
  state: WidgetSnapshotState.accountRemoved,
  title: l10n.widgetAccountRemovedTitle,
  generatedAt: now,
  validUntil: now.add(const Duration(days: 3650)),
  message: WidgetText(
    l10n.widgetAccountRemovedTitle,
    body: l10n.widgetChooseAnotherList,
  ),
  messageLink: const WidgetOpenLink().toUri().toString(),
);

final class _AccountBuild {
  new _({
    required this.db,
    required this.texts,
    required this.account,
    required this.now,
    required this.projects,
    required this.labels,
    required this.state,
    required this.settings,
    required this.showTaskTitles,
  }) : projectsById = {for (final project in projects) project.id: project},
       archived = archivedProjectIds(projects).toSet(),
       formatter = texts.formatter(DisplaySettings.from(settings)),
       filters = LocalFilters(db, now: () => now);

  static Future<_AccountBuild> load(
    AppDatabase db,
    WidgetTexts texts,
    WidgetAccount account,
    DateTime now, {
    required bool showTaskTitles,
  }) async {
    final state = await db.syncStateDao.readAll();
    return _AccountBuild._(
      db: db,
      texts: texts,
      account: account,
      now: now,
      projects: await db.projectsDao.loadAll(),
      labels: await db.labelsDao.loadAll(),
      state: state,
      settings: decodeUserSettings(state[SyncStateKeys.userSettings]),
      showTaskTitles: showTaskTitles,
    );
  }

  final AppDatabase db;
  final WidgetTexts texts;
  final WidgetAccount account;
  final DateTime now;
  final List<Project> projects;
  final List<Label> labels;
  final Map<String, String> state;
  final UserSettings settings;
  final bool showTaskTitles;
  final Map<int, Project> projectsById;
  final Set<int> archived;
  final MomentFormatter formatter;
  final LocalFilters filters;

  AppLocalizations get l10n => texts.l10n;

  late final Future<List<Task>> activeOpenTasks = db.tasksDao
      .loadActiveOpenTasks();

  late final bool canAddTasks =
      defaultProjectFor(
        projects,
        defaultProjectId: settings.defaultProjectId,
      ) !=
      null;

  Future<WidgetSnapshot> snapshot(WidgetKind kind) async => switch (kind) {
    TodayKind() => _list(
      kind,
      title: l10n.sectionToday,
      tasks: await _today(),
      empty: WidgetText(
        l10n.overviewEmptyTitle,
        body: l10n.widgetTodayEmptyBody,
      ),
    ),
    UpcomingKind(:final days) => _list(
      kind,
      title: l10n.widgetUpcomingTitle(days),
      tasks: await _upcoming(days),
      empty: WidgetText(l10n.upcomingEmptyTitle, body: l10n.upcomingEmptyBody),
    ),
    OverdueKind() => _list(
      kind,
      title: l10n.sectionOverdue,
      tasks: [
        for (final task in await activeOpenTasks)
          if (task.isOverdue(now)) task,
      ],
      empty: WidgetText(l10n.widgetOverdueEmptyTitle),
    ),
    ProjectTasksKind(:final projectId) => await _project(kind, projectId),
    LabelTasksKind(:final labelId) => await _label(kind, labelId),
    FavoritesKind() => _list(
      kind,
      title: l10n.projectFavouritesTitle,
      tasks: await db.tasksDao.loadFavoriteTasks(),
      empty: WidgetText(
        l10n.favoritesEmptyTitle,
        body: l10n.favoritesEmptyBody,
      ),
    ),
    SavedFilterKind() => await _savedFilter(kind),
    QuickAddKind() => _quickAdd(kind),
  };

  /// The Overview's source (its saved filter, evaluated here or as last
  /// downloaded, else every open task outside archived projects), then its
  /// overdue and today sections.
  Future<List<Task>> _today() async {
    final filter = overviewFilterIn(state);
    final List<Task> tasks;
    if (filter == null) {
      tasks = await activeOpenTasks;
    } else if (await _openTasksOfSavedFilter(filter) case final local?) {
      tasks = local;
    } else {
      tasks = (await db.tasksDao.loadOpenTasksInList(
        overviewSnapshotKey(filter.projectId),
      )).tasks;
    }
    return [
      for (final section in groupTasksByDueDate(tasks, now))
        if (section.group == DueGroup.overdue ||
            section.group == DueGroup.today)
          ...section.tasks,
    ];
  }

  Future<List<Task>> _upcoming(int days) async {
    final selection = selectUpcoming(
      await activeOpenTasks,
      range: DateRange(from: now, to: evaluateDatemath('now+${days}d', now)),
      now: now,
      showOverdue: true,
      showWithoutDueDate: false,
    );
    return [...selection.overdue, ...selection.inRange];
  }

  /// The project's first list view, in its filter and the sort the user
  /// left it in, the open top-level rows; a project without a list view
  /// lists its open tasks.
  Future<WidgetSnapshot> _project(WidgetKind kind, int projectId) async {
    final project = projectsById[projectId];
    if (project == null) return _gone(kind, l10n.projectGoneTitle);
    final view = shownViewsOf(project)
        .where((view) => view.kind == ProjectViewKind.list)
        .firstOrNull;
    final viewId = view?.id ?? 0;
    final source = await db.tasksDao.loadProjectList(
      projectId,
      viewId: viewId,
      includeDone: false,
      matchingIds: await filters.matchingInProject(
        projectId,
        view?.filter,
        timezoneSetting: settings.timezone,
      ),
    );
    final preferences = await LocalListPreferences(db)
        .watchView(listKeyFor(projectId: projectId, viewId: viewId))
        .first;
    final model = buildProjectListModel(
      source,
      kind: classifyViewFilter(view?.filter),
      preferences: preferences.copyWith(showDone: false),
    );
    final canAdd =
        !archived.contains(projectId) && ProjectAccess.of(project).canAddTasks;
    return _list(
      kind,
      title: project.displayTitle(l10n),
      tasks: [
        for (final row in model.rows)
          if (row.depth == 0 && !row.task.done) row.task,
      ],
      empty: WidgetText(l10n.projectTasksEmptyTitle),
      listProjectId: projectId,
      newTaskProjectId: canAdd ? projectId : null,
    );
  }

  Future<WidgetSnapshot> _label(WidgetKind kind, int labelId) async {
    final label = labels.where((label) => label.id == labelId).firstOrNull;
    if (label == null) return _gone(kind, l10n.labelTasksGoneTitle);
    final ids = await filters.matchingForSavedFilter(
      SavedFilterDefinition(
        filter: ViewFilter(filter: 'done = false && labels in $labelId'),
      ),
      timezoneSetting: '',
      openOnly: true,
    );
    return _list(
      kind,
      title: label.title,
      tasks: await db.tasksDao.loadOpenTasksAmong(ids ?? const {}),
      empty: WidgetText(
        l10n.labelTasksEmptyTitle,
        body: l10n.labelTasksEmptyBody(label.title),
      ),
    );
  }

  /// Evaluated here when the device can, else the last download; a guest
  /// has none.
  Future<WidgetSnapshot> _savedFilter(SavedFilterKind kind) async {
    final filter = account.isGuest
        ? null
        : decodeSavedFilters(state[SyncStateKeys.savedFilters])
              .where((filter) => filter.projectId == kind.pseudoProjectId)
              .firstOrNull;
    if (filter == null) return _gone(kind, l10n.smartListFilterGoneTitle);
    final title = projectDisplayTitle(
      l10n,
      filter.title,
      projectId: filter.projectId,
    );
    final tasks =
        await _openTasksOfSavedFilter(filter) ??
        (await db.tasksDao.loadOpenTasksInList(
          savedFilterSnapshotKey(filter.projectId),
        )).tasks;
    return _list(
      kind,
      title: title,
      tasks: tasks,
      empty: WidgetText(
        l10n.projectTasksEmptyTitle,
        body: l10n.overviewFilterEmptyBody(title),
      ),
    );
  }

  Future<List<Task>?> _openTasksOfSavedFilter(SavedFilterRef filter) async {
    final definition = filter.definition;
    if (definition == null || !evaluatesLocally(definition)) return null;
    final ids = await filters.matchingForSavedFilter(
      definition,
      timezoneSetting: settings.timezone,
      openOnly: true,
    );
    return await db.tasksDao.loadOpenTasksAmong(ids ?? const {});
  }

  WidgetSnapshot _quickAdd(WidgetKind kind) => WidgetSnapshot(
    key: snapshotKey(account.id, kind),
    accountId: account.id,
    state: account.state,
    title: l10n.newTask,
    subtitle: _subtitle,
    generatedAt: now,
    validUntil: nextLocalMidnight(now),
    message: _sessionMessage,
    messageLink: _sessionMessageLink,
    empty: canAddTasks ? null : WidgetText(l10n.newTaskNoProjectError),
    newTaskLink: canAddTasks ? _newTaskLink(null) : null,
    newTaskLabel: l10n.newTask,
  );

  WidgetSnapshot _list(
    WidgetKind kind, {
    required String title,
    required List<Task> tasks,
    required WidgetText empty,
    int? listProjectId,
    int? newTaskProjectId,
  }) {
    final rows = [
      if (showTaskTitles)
        for (final task in tasks.take(WidgetSnapshot.maxRows))
          _row(task, listProjectId: listProjectId),
    ];
    final validUntil = nextLocalMidnight(now);
    final more = tasks.length - rows.length;
    return WidgetSnapshot(
      key: snapshotKey(account.id, kind),
      accountId: account.id,
      state: account.state,
      title: title,
      subtitle: _subtitle,
      generatedAt: now,
      validUntil: validUntil,
      changesAt: {
        for (final row in rows)
          if (row.dueAt case final due?
              when row.tone == WidgetDueTone.today &&
                  due.isAfter(now) &&
                  due.isBefore(validUntil))
            due,
      }.toList()..sort(),
      rows: rows,
      total: tasks.length,
      moreLabel: more > 0 && showTaskTitles ? l10n.widgetMoreTasks(more) : null,
      countLabel: l10n.widgetTaskCount(tasks.length),
      // Both renderers show this text in place of the rows.
      empty: showTaskTitles || tasks.isEmpty
          ? empty
          : WidgetText(
              l10n.widgetTaskCount(tasks.length),
              body: l10n.widgetTitlesHiddenHint(tasks.length),
            ),
      message: _sessionMessage,
      messageLink: _sessionMessageLink,
      link: kind.listLink(account.id)?.toUri().toString(),
      newTaskLink: canAddTasks
          ? _newTaskLink(listProjectId == null ? null : newTaskProjectId)
          : null,
      newTaskLabel: l10n.newTask,
    );
  }

  WidgetSnapshot _gone(WidgetKind kind, String title) => WidgetSnapshot(
    key: snapshotKey(account.id, kind),
    accountId: account.id,
    state: WidgetSnapshotState.gone,
    title: title,
    subtitle: _subtitle,
    generatedAt: now,
    validUntil: nextLocalMidnight(now),
    message: WidgetText(title, body: l10n.widgetChooseAnotherList),
    messageLink: WidgetOpenLink(accountId: account.id).toUri().toString(),
  );

  WidgetRow _row(Task task, {int? listProjectId}) {
    final project = projectsById[task.projectId];
    final due = task.dueDate;
    final dueLabel = due == null
        ? null
        : texts.dueLabel(due, now: now, formatter: formatter);
    final tone = texts.tone(task, now);
    final priority =
        PriorityFlag.showsOnRow(
          task,
          minimumPriority: settings.effectiveMinimumPriority,
        )
        ? texts.priority(task.priority)
        : null;
    final projectTitle = project != null && task.projectId != listProjectId
        ? project.displayTitle(l10n)
        : null;
    final identifier = task.id > 0 ? task.displayIdentifier : null;
    final details = [?identifier, ?projectTitle].join(' · ');
    return WidgetRow(
      taskId: task.id,
      title: task.title,
      dueLabel: dueLabel,
      dueAt: due,
      tone: tone,
      priorityLabel: priority,
      priorityLevel: priority == null ? null : task.priority.value,
      projectTitle: projectTitle,
      projectColor: _color(project?.hexColor),
      canDone:
          project != null &&
          !archived.contains(project.id) &&
          ProjectAccess.of(project).canChangeTasks,
      semanticsLabel: [
        task.title,
        if (details.isNotEmpty) details,
        if (dueLabel != null && tone == WidgetDueTone.overdue)
          l10n.taskOverdueSemantics(dueLabel)
        else if (dueLabel != null)
          l10n.taskDueSemantics(dueLabel),
        if (priority != null) l10n.prioritySemantics(priority),
      ].join('\n'),
      doneLabel: l10n.widgetMarkDone(task.title),
      link: WidgetTaskLink(
        accountId: account.id,
        taskId: task.id,
      ).toUri().toString(),
    );
  }

  String? get _subtitle => account.showsAccount
      ? l10n.widgetAccountSubtitle(account.title, account.host)
      : null;

  WidgetText? get _sessionMessage => switch (account.state) {
    WidgetSnapshotState.needsReauth => WidgetText(
      l10n.reauthTitle,
      action: l10n.reauthAction,
    ),
    WidgetSnapshotState.guestEnded => WidgetText(
      l10n.guestReauthTitle,
      action: l10n.guestOpenLinkAgain,
    ),
    _ => null,
  };

  String? get _sessionMessageLink => account.sessionEnded
      ? WidgetAccountLink(accountId: account.id).toUri().toString()
      : null;

  String _newTaskLink(int? projectId) => WidgetNewTaskLink(
    accountId: account.id,
    projectId: projectId,
  ).toUri().toString();

  WidgetCatalog catalog() {
    WidgetCatalogList smart(WidgetKind kind, String title) => WidgetCatalogList(
      config: WidgetConfig(accountId: account.id, kind: kind),
      section: WidgetCatalogSection.smart,
      title: title,
    );
    final ancestors = <String>[];
    WidgetCatalogList project(ProjectTreeRow row) {
      final title = row.node.project.displayTitle(l10n);
      ancestors.length = row.depth;
      final parent = ancestors.isEmpty ? null : ancestors.join(' › ');
      ancestors.add(title);
      return WidgetCatalogList(
        config: WidgetConfig(
          accountId: account.id,
          kind: ProjectTasksKind(row.node.project.id),
        ),
        section: WidgetCatalogSection.project,
        title: title,
        color: _color(row.node.project.hexColor),
        writable: ProjectAccess.of(row.node.project).canAddTasks,
        depth: row.depth,
        parent: parent,
      );
    }

    return WidgetCatalog(
      account: WidgetCatalogAccount(
        id: account.id,
        name: account.title,
        host: account.host,
        isGuest: account.isGuest,
        supportsV2: account.supportsV2,
      ),
      generatedAt: now,
      canAddTasks: canAddTasks,
      lists: [
        smart(const TodayKind(), l10n.sectionToday),
        for (final days in WidgetKind.upcomingDays)
          smart(UpcomingKind(days), l10n.widgetUpcomingTitle(days)),
        smart(const OverdueKind(), l10n.sectionOverdue),
        smart(const FavoritesKind(), l10n.projectFavouritesTitle),
        for (final row in flattenProjectTree(
          buildProjectTree(projects),
          collapsedIds: const {},
        ))
          project(row),
        for (final label in [
          ...labels,
        ]..sort((a, b) => compareTitles(a.title, b.title)))
          WidgetCatalogList(
            config: WidgetConfig(
              accountId: account.id,
              kind: LabelTasksKind(label.id),
            ),
            section: WidgetCatalogSection.label,
            title: label.title,
            color: _color(label.hexColor),
          ),
        if (!account.isGuest)
          for (final filter in sortedByTitle(
            decodeSavedFilters(state[SyncStateKeys.savedFilters]),
          ))
            WidgetCatalogList(
              config: WidgetConfig(
                accountId: account.id,
                kind: SavedFilterKind(filter.filterId),
              ),
              section: WidgetCatalogSection.savedFilter,
              title: projectDisplayTitle(
                l10n,
                filter.title,
                projectId: filter.projectId,
              ),
            ),
      ],
    );
  }
}

/// `rrggbb` from the server's hex colour, which may carry a `#`; null when
/// unset.
String? _color(String? hex) {
  final value = hex?.replaceFirst('#', '').toLowerCase() ?? '';
  return RegExp(r'^[0-9a-f]{6}$').hasMatch(value) ? value : null;
}
