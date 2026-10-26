import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/label_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';

final _log = Logger('AccountData');

const _labelMissing = 8002;

/// Labels from the account's database; a create goes to the server first.
/// A create without an answer may still have reached the server, which
/// keeps labels of the same title side by side: the label is looked for
/// before the failure is reported and before the next create of that
/// title. Changes and deletes are online too, stored once answered, and
/// a quiet [SyncEngine.refreshAfterWrite] follows them.
final class LocalLabelRepository implements LabelRepository {
  new(this._db, this._write, this._read, {this._sync, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// How far before an unanswered create the lookup reaches: the server's
  /// `created` is its own clock; the same hour of skew the outbox allows.
  static const lostResponseWindow = Duration(hours: 1);

  final AppDatabase _db;
  final VikunjaWriteClient _write;
  final VikunjaReadClient _read;
  final SyncEngine? _sync;
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

  @override
  Future<Label> findOrCreate(NewLabel label) async {
    if (await _titled(label.title) case final found?) {
      return await _store(found);
    }
    return await create(label);
  }

  @override
  Future<Label> update(int id, LabelChanges changes) async {
    if (changes.title case final title? when labelTitleProblem(title) != null) {
      throw ArgumentError.value(changes, 'changes', 'has no valid title');
    }
    final Label answer;
    try {
      answer = await _write.labels.update(id, changes);
    } on NotFound catch (failure) {
      if (failure.code == _labelMissing) {
        await _db.labelsDao.remove(id);
        _settle('Label $id was gone');
      }
      rethrow;
    }
    final stored = answer.createdBy != null
        ? answer
        : Label(
            id: answer.id,
            title: answer.title,
            description: answer.description,
            hexColor: answer.hexColor,
            createdBy: await _storedCreator(id),
            created: answer.created,
            updated: answer.updated,
          );
    await _db.labelsDao.upsertAll([stored]);
    _settle('Changed label $id');
    return stored;
  }

  @override
  Future<void> delete(int id) async {
    await _write.labels.delete(id);
    await _db.labelsDao.remove(id);
    _settle('Deleted label $id');
  }

  Future<User?> _storedCreator(int id) async {
    for (final label in await _db.labelsDao.loadAll()) {
      if (label.id == id) return label.createdBy;
    }
    return null;
  }

  void _settle(String done) {
    _log.fine(done);
    final sync = _sync;
    if (sync == null) return;
    unawaited(
      sync.refreshAfterWrite().then<void>(
        (_) {},
        onError: (Object error) =>
            _log.fine('Sync after a label change failed: ${error.runtimeType}'),
      ),
    );
  }

  /// The server's label titled [title], ignoring case; of several the one
  /// with the same case, else the oldest.
  Future<Label?> _titled(String title) async {
    final matches = await _sameTitleOnServer(title);
    if (matches.isEmpty) return null;
    matches.sort((a, b) => a.id.compareTo(b.id));
    return matches.where((label) => label.title == title).firstOrNull ??
        matches.first;
  }

  /// Every label on the server titled [title], ignoring case, from all
  /// pages of a search for it.
  Future<List<Label>> _sameTitleOnServer(String title) async {
    final lower = title.toLowerCase();
    final matches = <Label>[];
    for (var page = 1; ; page++) {
      final current = await _read.labels.list(page: page, search: title);
      matches.addAll(
        current.items.where((label) => label.title.toLowerCase() == lower),
      );
      if (!current.hasMore) return matches;
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
    for (final label in await _sameTitleOnServer(title)) {
      final created = label.created;
      if (label.title != title ||
          stored.contains(label.id) ||
          created == null ||
          created.isBefore(from)) {
        continue;
      }
      if (found == null || label.id > found.id) found = label;
    }
    return found;
  }

  @override
  void dispose() {}
}
