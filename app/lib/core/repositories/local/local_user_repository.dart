import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/user_repository.dart';

/// Searches on the server and remembers what it found.
final class LocalUserRepository implements UserRepository {
  new(this._db, this._read);

  final AppDatabase _db;
  final VikunjaReadClient _read;

  @override
  Future<List<User>> searchAssignees(int projectId, String query) async {
    final found = await _read.users.searchProjectUsers(
      projectId,
      query: query.trim(),
    );
    await _db.usersDao.upsertAll(found);
    return found;
  }

  @override
  Future<List<User>> search(String query) async {
    final found = await _read.users.searchUsers(query.trim());
    await _db.usersDao.upsertAll(found);
    return found;
  }

  @override
  Future<List<User>> knownUsers() => _db.usersDao.loadAll();

  @override
  Stream<List<User>> watchKnownUsers() => _db.usersDao.watchAll();

  @override
  void dispose() {}
}
