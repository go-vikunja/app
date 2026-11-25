import 'package:vikunja_mobile/core/db/app_database.dart';

/// The card and row moves the server accepted, applied to a database's
/// boards and list snapshots (`KanbanDao.applySentPlacements`,
/// `ListSnapshotsDao.applySentPositions`), in the order they were applied.
/// A view's download that started before one of them read the server
/// before that move and keeps the applied place of the task instead of
/// what it read.
///
/// Kept in memory: views are downloaded only by the app in front, whose
/// sender applies the moves.
final class SentViewMoves {
  factory of(AppDatabase db) => _ofDatabase[db] ??= SentViewMoves._();

  new _();

  static final _ofDatabase = Expando<SentViewMoves>();

  var _clock = 0;
  final _byView = <int, Map<int, int>>{};

  /// Where a download that starts now stands among the applied moves.
  int get mark => _clock;

  void record(int viewId, int taskId) =>
      (_byView[viewId] ??= {})[taskId] = ++_clock;

  /// The tasks of [viewId] whose move was applied after [mark]. The moves
  /// applied before it are forgotten: the download that took [mark] read
  /// the server after them, and the downloads of a view run one after
  /// another.
  Set<int> since(int viewId, int mark) {
    final moves = _byView[viewId];
    if (moves == null) return const {};
    moves.removeWhere((_, at) => at <= mark);
    if (moves.isEmpty) _byView.remove(viewId);
    return {...moves.keys};
  }
}
