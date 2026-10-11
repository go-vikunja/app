import 'package:vikunja_domain/vikunja_domain.dart';

/// The labels the account can attach, as this device knows them.
abstract interface class LabelRepository {
  /// Ordered by title, case-insensitively.
  Stream<List<Label>> watchAll();

  /// Creates the label on the server right away, so it needs a connection,
  /// and stores the answer locally; attaching it to a task then works
  /// offline like any other change. A create whose answer was lost is
  /// looked for on the server instead of being made twice. Throws the
  /// `VikunjaFailure`.
  Future<Label> create(NewLabel label);

  void dispose();
}
