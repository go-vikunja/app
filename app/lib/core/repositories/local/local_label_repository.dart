import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/label_ops_dao.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/label_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';
import 'package:vikunja_mobile/core/text/title_order.dart';

final _log = Logger('AccountData');

const _labelMissing = 8002;

/// Labels from the account's database. A create is local first: the label
/// is stored under a temporary id with its create queued in the outbox,
/// which the [OutboxSender] (`outbox`) drains; a change or delete of such
/// a label, or of one with a change still queued, is queued too. Changes
/// and deletes of the server's other labels are online, stored once
/// answered, and a quiet [SyncEngine.refreshAfterWrite] follows them.
final class LocalLabelRepository implements LabelRepository {
  new(
    this._db,
    this._write, {
    this._outbox,
    this._sync,
    DateTime Function()? now,
    User? Function()? currentUser,
  }) : _now = now ?? DateTime.now,
       _currentUser = currentUser ?? _unknownUser;

  static User? _unknownUser() => null;

  final AppDatabase _db;
  final VikunjaWriteClient _write;
  final OutboxSender? _outbox;
  final SyncEngine? _sync;
  final DateTime Function() _now;
  final User? Function() _currentUser;

  @override
  Stream<List<Label>> watchAll() => _db.labelsDao.watchAll().map(
    (labels) => [...labels]
      ..sort((a, b) {
        final byTitle = compareTitles(a.title, b.title);
        return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
      }),
  );

  @override
  Stream<Label?> watchLabel(int id) => _db.labelsDao.watchLabel(id);

  @override
  Future<Label> create(NewLabel label) => _queueCreate(label, adopt: false);

  @override
  Future<Label> findOrCreate(NewLabel label) async {
    final title = withoutNul(label.title).toLowerCase();
    final matches = [
      for (final stored in await _db.labelsDao.loadAll())
        if (stored.title.toLowerCase() == title) stored,
    ]..sort(_oldestFirst);
    final exact = withoutNul(label.title);
    final found =
        matches.where((stored) => stored.title == exact).firstOrNull ??
        matches.firstOrNull;
    return found ?? await _queueCreate(label, adopt: true);
  }

  /// The server's labels by id, then the ones created here in the order
  /// they were.
  static int _oldestFirst(Label a, Label b) {
    if ((a.id > 0) != (b.id > 0)) return a.id > 0 ? -1 : 1;
    return a.id.abs().compareTo(b.id.abs());
  }

  Future<Label> _queueCreate(NewLabel label, {required bool adopt}) async {
    final sent = _asStored(label);
    if (labelTitleProblem(sent.title) != null) {
      throw ArgumentError.value(label, 'label', 'has no valid title');
    }
    final created = await _db.labelOpsDao.queueCreate(
      sent,
      now: _now(),
      createdBy: _currentUser(),
      adopt: adopt,
    );
    _log.fine('Queued the create of label ${created.id}');
    _drainQuietly();
    return created;
  }

  /// [label] with the title the server stores, without U+0000, so the
  /// search and the title matches find the label it made of it.
  static NewLabel _asStored(NewLabel label) => NewLabel(
    title: withoutNul(label.title),
    hexColor: label.hexColor,
    description: label.description,
  );

  @override
  Future<Label> update(int id, LabelChanges changes) async {
    if (changes.title case final title? when labelTitleProblem(title) != null) {
      throw ArgumentError.value(changes, 'changes', 'has no valid title');
    }
    final (queueing, queued) = await _db.labelOpsDao.queueUpdate(
      id,
      changes,
      now: _now(),
    );
    switch (queueing) {
      case LabelQueueing.queued:
        _drainQuietly();
        return queued!;
      case LabelQueueing.gone:
        throw const NotFound(code: _labelMissing);
      case LabelQueueing.online:
        break;
    }
    final serverId = await _db.labelsDao.resolveId(id);
    final Label answer;
    try {
      answer = await _write.labels.update(serverId, changes);
    } on NotFound catch (failure) {
      if (failure.code == _labelMissing) {
        await _db.labelsDao.remove(serverId);
        _settle('Label $serverId was gone');
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
            createdBy: (await _db.labelsDao.find(serverId))?.createdBy,
            created: answer.created,
            updated: answer.updated,
          );
    await _db.labelsDao.upsertAll([stored]);
    _settle('Changed label $serverId');
    return stored;
  }

  @override
  Future<void> delete(int id) async {
    switch (await _db.labelOpsDao.queueDelete(id, now: _now())) {
      case LabelQueueing.queued:
        _drainQuietly();
        return;
      case LabelQueueing.gone:
        return;
      case LabelQueueing.online:
        break;
    }
    final serverId = await _db.labelsDao.resolveId(id);
    await _write.labels.delete(serverId);
    await _db.labelsDao.remove(serverId);
    _settle('Deleted label $serverId');
  }

  @override
  Stream<Set<int>> watchPendingIds() => _db.labelOpsDao.watchPendingIds();

  @override
  Stream<Map<int, int>> watchRemaps() => _db.labelsDao.watchRemaps();

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

  /// The write is stored; the send reports through the outbox state and
  /// the sync problems.
  void _drainQuietly() {
    final outbox = _outbox;
    if (outbox == null) return;
    unawaited(
      outbox.drain().then<void>(
        (_) {},
        onError: (Object error) =>
            _log.warning('Outbox drain failed: ${error.runtimeType}'),
      ),
    );
  }

  @override
  void dispose() {}
}
