import 'package:vikunja_domain/vikunja_domain.dart';

/// The people tasks can be assigned to.
abstract interface class UserRepository {
  /// The users with access to [projectId] matching [query], from the
  /// server, so it needs a connection; throws the `VikunjaFailure`. The
  /// results are stored locally, so assigning one of them works offline.
  Future<List<User>> searchAssignees(int projectId, String query);

  /// Everyone this device knows from synced tasks and earlier searches,
  /// for suggestions while offline.
  Future<List<User>> knownUsers();

  /// [knownUsers] and its changes.
  Stream<List<User>> watchKnownUsers();

  void dispose();
}
