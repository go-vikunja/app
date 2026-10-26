import 'package:vikunja_domain/vikunja_domain.dart';

/// The people tasks can be assigned to and projects shared with.
abstract interface class UserRepository {
  /// The users with access to [projectId] matching [query], from the
  /// server, so it needs a connection; throws the `VikunjaFailure`. The
  /// results are stored locally, so assigning one of them works offline.
  Future<List<User>> searchAssignees(int projectId, String query);

  /// Anyone on the server matching [query], to share with or add to a
  /// team: by exact username in any case, by name or email only for people
  /// who allow it. A blank query finds nobody, without a request. Needs a
  /// connection; the results are stored like [searchAssignees]'.
  Future<List<User>> search(String query);

  /// Everyone this device knows from synced tasks and earlier searches,
  /// for suggestions while offline.
  Future<List<User>> knownUsers();

  /// [knownUsers] and its changes.
  Stream<List<User>> watchKnownUsers();

  void dispose();
}
