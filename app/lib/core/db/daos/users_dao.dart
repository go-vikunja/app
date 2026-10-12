import 'package:drift/drift.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/mappers/user_mappers.dart';
import 'package:vikunja_mobile/core/db/tables/users.dart';

part 'users_dao.g.dart';

@DriftAccessor(tables: [Users])
final class UsersDao extends DatabaseAccessor<AppDatabase>
    with _$UsersDaoMixin {
  new(super.attachedDatabase);

  Future<List<User>> loadAll() async {
    final rows = await (select(
      users,
    )..orderBy([(u) => OrderingTerm.asc(u.id)])).get();
    return rows.map(userFromRow).toList(growable: false);
  }

  Future<User?> find(int id) async {
    final row = await (select(
      users,
    )..where((u) => u.id.equals(id))).getSingleOrNull();
    return row == null ? null : userFromRow(row);
  }

  Stream<List<User>> watchAll() =>
      (select(users)..orderBy([(u) => OrderingTerm.asc(u.id)])).watch().map(
        (rows) => rows.map(userFromRow).toList(growable: false),
      );

  Future<void> upsertAll(Iterable<User> all) => batch(
    (b) => b.insertAllOnConflictUpdate(users, all.map(userRow).toList()),
  );
}
