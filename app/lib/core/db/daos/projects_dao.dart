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

  /// Views go with their project through the foreign key.
  Future<int> purgeNotIn(Iterable<int> ids) =>
      (delete(projects)..where((p) => p.id.isNotIn(ids))).go();

  Future<int> purge(Iterable<int> ids) =>
      (delete(projects)..where((p) => p.id.isIn(ids))).go();
}
