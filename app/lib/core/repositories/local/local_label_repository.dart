import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/label_repository.dart';

/// Labels from the account's database; a create goes to the server first.
/// A create without an answer may still have reached the server, which
/// keeps labels of the same title side by side: the label is looked for
/// before the failure is reported and before the next create of that
/// title.
final class LocalLabelRepository implements LabelRepository {
  new(this._db, this._write, this._read, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// How far before an unanswered create the lookup reaches: the server's
  /// `created` is its own clock; the same hour of skew the outbox allows.
  static const lostResponseWindow = Duration(hours: 1);

  final AppDatabase _db;
  final VikunjaWriteClient _write;
  final VikunjaReadClient _read;
  final DateTime Function() _now;

  /// Titles whose create may have reached the server unanswered, with the
  /// time of the first such attempt.
  final _unconfirmed = <String, DateTime>{};

  @override
  Stream<List<Label>> watchAll() => _db.labelsDao.watchAll().map(
    (labels) => [...labels]
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())),
  );

  @override
  Future<Label> create(NewLabel label) async {
    if (_unconfirmed[label.title] case final since?) {
      if (await _createdSince(label.title, since) case final found?) {
        return await _store(found);
      }
    }
    final attemptedAt = _now();
    try {
      return await _store(await _write.labels.create(label));
    } on VikunjaFailure catch (failure) {
      if (failure is! NetworkFailure && failure is! ServerFailure) rethrow;
      final since = _unconfirmed.putIfAbsent(label.title, () => attemptedAt);
      final found = await _createdSinceIfReachable(label.title, since);
      if (found == null) rethrow;
      return await _store(found);
    }
  }

  Future<Label> _store(Label label) async {
    _unconfirmed.remove(label.title);
    await _db.labelsDao.upsertAll([label]);
    return label;
  }

  Future<Label?> _createdSinceIfReachable(String title, DateTime since) async {
    try {
      return await _createdSince(title, since);
    } on VikunjaFailure {
      return null;
    }
  }

  /// The newest label titled exactly [title] that the server created since
  /// [lostResponseWindow] before [since] and this device has no row for.
  Future<Label?> _createdSince(String title, DateTime since) async {
    final stored = {
      for (final label in await _db.labelsDao.loadAll()) label.id,
    };
    final from = since.subtract(lostResponseWindow);
    Label? found;
    for (var page = 1; ; page++) {
      final current = await _read.labels.list(page: page, search: title);
      for (final label in current.items) {
        final created = label.created;
        if (label.title != title ||
            stored.contains(label.id) ||
            created == null ||
            created.isBefore(from)) {
          continue;
        }
        if (found == null || label.id > found.id) found = label;
      }
      if (!current.hasMore) return found;
    }
  }

  @override
  void dispose() {}
}
