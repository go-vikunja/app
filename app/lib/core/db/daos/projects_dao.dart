import 'package:drift/drift.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/mappers/project_mappers.dart';
import 'package:vikunja_mobile/core/db/mappers/user_mappers.dart';
import 'package:vikunja_mobile/core/db/tables/projects.dart';
import 'package:vikunja_mobile/core/db/tables/users.dart';
import 'package:vikunja_mobile/core/db/watch_tables.dart';

part 'projects_dao.g.dart';

@DriftAccessor(tables: [Projects, ProjectViews, Users])
final class ProjectsDao extends DatabaseAccessor<AppDatabase>
    with _$ProjectsDaoMixin {
  new(super.attachedDatabase);

  /// Ordered by position, then id; archived projects included.
  Stream<List<Project>> watchAll() =>
      watchTables({projects, projectViews, users}, loadAll);

  Future<List<Project>> loadAll() async {
    final query =
        select(projects)
            .join([leftOuterJoin(users, users.id.equalsExp(projects.ownerId))])
          ..orderBy([
            OrderingTerm.asc(projects.position),
            OrderingTerm.asc(projects.id),
          ]);
    final rows = await query.get();
    final views =
        await (select(projectViews)..orderBy([
              (v) => OrderingTerm.asc(v.position),
              (v) => OrderingTerm.asc(v.id),
            ]))
            .get();
    final viewsByProject = <int, List<ProjectViewRow>>{};
    for (final view in views) {
      viewsByProject.putIfAbsent(view.projectId, () => []).add(view);
    }
    return [
      for (final row in rows)
        projectFromRow(
          row.readTable(projects),
          views: viewsByProject[row.readTable(projects).id] ?? const [],
          owner: switch (row.readTableOrNull(users)) {
            final user? => userFromRow(user),
            null => null,
          },
        ),
    ];
  }

  /// Pseudo projects are skipped; their views are replaced wholesale.
  Future<void> upsertAll(Iterable<Project> all) {
    final real = all.where((project) => !project.isPseudo).toList();
    if (real.isEmpty) return Future.value();
    return batch((b) {
      b
        ..insertAllOnConflictUpdate(users, [
          for (final project in real)
            if (project.owner case final owner?) userRow(owner),
        ])
        ..insertAllOnConflictUpdate(projects, [
          for (final project in real) projectRow(project).toCompanion(false),
        ])
        ..deleteWhere(
          projectViews,
          (v) => v.projectId.isIn([for (final project in real) project.id]),
        )
        ..insertAllOnConflictUpdate(projectViews, [
          for (final project in real)
            for (final view in project.views)
              projectViewRow(view).toCompanion(false),
        ]);
    });
  }

  Future<Project?> loadProject(int projectId) async {
    final row = await (select(
      projects,
    )..where((p) => p.id.equals(projectId))).getSingleOrNull();
    if (row == null) return null;
    final views =
        await (select(projectViews)
              ..where((v) => v.projectId.equals(projectId))
              ..orderBy([
                (v) => OrderingTerm.asc(v.position),
                (v) => OrderingTerm.asc(v.id),
              ]))
            .get();
    final owner = switch (row.ownerId) {
      final ownerId? => await (select(
        users,
      )..where((u) => u.id.equals(ownerId))).getSingleOrNull(),
      null => null,
    };
    return projectFromRow(
      row,
      views: views,
      owner: owner == null ? null : userFromRow(owner),
    );
  }

  /// [projectId] and every stored project below it.
  Future<Set<int>> subtreeOf(int projectId) async {
    final query = selectOnly(projects)
      ..addColumns([projects.id, projects.parentProjectId]);
    final rows = [
      for (final row in await query.get())
        (
          id: row.read(projects.id)!,
          parent: row.read(projects.parentProjectId)!,
        ),
    ];
    final ids = {projectId};
    for (var grew = true; grew;) {
      grew = false;
      for (final row in rows) {
        if (ids.contains(row.parent) && ids.add(row.id)) grew = true;
      }
    }
    return ids;
  }

  /// Changes only the given fields of the stored project, as an edit
  /// answered by the server; an [identifier] renames the stored tasks of
  /// the project too (`TasksDao.renameIdentifiers`), as the server does
  /// without a trace a sync could see. The stored `updated` stays, so the
  /// next sync stores the whole project again.
  Future<void> updateProject(
    int projectId, {
    String? title,
    String? identifier,
    String? hexColor,
    int? parentProjectId,
    bool? isFavorite,
    double? position,
  }) => transaction(() async {
    await (update(projects)..where((p) => p.id.equals(projectId))).write(
      ProjectsCompanion(
        title: Value.absentIfNull(title),
        identifier: Value.absentIfNull(identifier),
        hexColor: Value.absentIfNull(hexColor),
        parentProjectId: Value.absentIfNull(parentProjectId),
        isFavorite: Value.absentIfNull(isFavorite),
        position: Value.absentIfNull(position),
      ),
    );
    if (identifier != null) {
      await attachedDatabase.tasksDao.renameIdentifiers(projectId, identifier);
    }
  });

  /// Archives or unarchives the stored project and every stored project
  /// below it, as the server does; returns their ids. The stored `updated`
  /// stays: the next sync then sees the change and, for an archive, pulls
  /// the tasks' changes through the projects, which `GET /tasks` no longer
  /// lists.
  Future<Set<int>> setArchived(int projectId, {required bool archived}) =>
      transaction(() async {
        final ids = await subtreeOf(projectId);
        await (update(projects)..where((p) => p.id.isIn(ids))).write(
          ProjectsCompanion(isArchived: Value(archived)),
        );
        return ids;
      });

  /// Removes the project and its stored subtree, as the server deletes it:
  /// their views, boards and list snapshots, and their tasks
  /// (`TasksDao.purgeInDeletedProjects`, unsent changes and their ops
  /// included). Returns the ids of the projects and of their views.
  Future<({Set<int> projectIds, Set<int> viewIds})> purgeSubtree(
    int projectId,
  ) => transaction(() async {
    final ids = await subtreeOf(projectId);
    final viewQuery = selectOnly(projectViews)
      ..addColumns([projectViews.id])
      ..where(projectViews.projectId.isIn(ids));
    final viewIds = {
      for (final row in await viewQuery.get()) row.read(projectViews.id)!,
    };
    await attachedDatabase.tasksDao.purgeInDeletedProjects(ids);
    await purge(ids);
    await attachedDatabase.kanbanDao.removeGoneViews();
    return (projectIds: ids, viewIds: viewIds);
  });

  /// Adds or replaces the view as the server answered it.
  Future<void> putView(ProjectView view) =>
      into(projectViews)
          .insertOnConflictUpdate(projectViewRow(view).toCompanion(false));

  /// Removes the view with its board and list snapshot.
  Future<void> removeView(int viewId) => transaction(() async {
    await (delete(projectViews)..where((v) => v.id.equals(viewId))).go();
    await attachedDatabase.kanbanDao.removeGoneViews();
  });

  Future<ProjectView?> loadView(int viewId) async {
    final row = await (select(
      projectViews,
    )..where((v) => v.id.equals(viewId))).getSingleOrNull();
    return row == null ? null : projectViewFromRow(row);
  }

  /// Changes only the given bucket ids of the view (0: none), as a done or
  /// default bucket change answered by the server; the next sync stores
  /// the whole view again.
  Future<void> setViewBuckets(
    int viewId, {
    int? doneBucketId,
    int? defaultBucketId,
  }) async {
    if (doneBucketId == null && defaultBucketId == null) return;
    await (update(projectViews)..where((v) => v.id.equals(viewId))).write(
      ProjectViewsCompanion(
        doneBucketId: Value.absentIfNull(doneBucketId),
        defaultBucketId: Value.absentIfNull(defaultBucketId),
      ),
    );
  }

  /// Changes only the project's position and parent, as a move answered by
  /// the server; the next sync stores the whole project again.
  Future<void> moveProject(
    int projectId, {
    required double position,
    required int parentProjectId,
  }) => (update(projects)..where((p) => p.id.equals(projectId))).write(
    ProjectsCompanion(
      position: Value(position),
      parentProjectId: Value(parentProjectId),
    ),
  );

  /// Views go with their project through the foreign key.
  Future<int> purgeNotIn(Iterable<int> ids) =>
      (delete(projects)..where((p) => p.id.isNotIn(ids))).go();

  Future<int> purge(Iterable<int> ids) =>
      (delete(projects)..where((p) => p.id.isIn(ids))).go();
}
