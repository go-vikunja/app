import 'package:drift/drift.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/db/mappers/label_mappers.dart';
import 'package:vikunja_mobile/core/db/mappers/user_mappers.dart';
import 'package:vikunja_mobile/core/db/tables/label_id_remaps.dart';
import 'package:vikunja_mobile/core/db/tables/labels.dart';
import 'package:vikunja_mobile/core/db/tables/outbox.dart';
import 'package:vikunja_mobile/core/db/tables/sync_state.dart';
import 'package:vikunja_mobile/core/db/tables/tasks.dart';
import 'package:vikunja_mobile/core/db/tables/users.dart';
import 'package:vikunja_mobile/core/db/watch_tables.dart';
import 'package:vikunja_mobile/core/outbox/apply_task_changes.dart';
import 'package:vikunja_mobile/core/outbox/label_op_json.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';

part 'label_ops_dao.g.dart';

/// How a label change was taken.
enum LabelQueueing {
  /// Stored here and queued, or folded into the label's unsent create.
  queued,

  /// A label the server has, with nothing of it queued: the change goes to
  /// the server at once.
  online,

  /// The label is not here (deleted, discarded or never known).
  gone,
}

/// The label ops of the outbox: a label created here lives under a
/// temporary negative id (the `sync_state` counter [localLabelIdsKey],
/// never reused) as an ordinary label row until its create is answered;
/// then [completeCreate] moves the row, its tasks and every queued
/// reference to the server id and records the remap.
///
/// While the create has not left the device (never sent, or refused) an
/// edit folds into it, unless it is one from `findOrCreate` (see
/// [queueUpdate]); once it may be on the server (in flight, or sent
/// without an answer) an edit queues behind it under the temporary id. A
/// delete cancels a create that is not in flight, whatever its `sent_at`,
/// with the row, its tasks and its queued adds and edits, without a
/// request; behind one in flight it queues under the temporary id, and the
/// create's next attempt goes with it, without a request (see
/// [cancelDeletedCreate]). An edit or a delete of a server label with ops
/// queued queues behind them. A task update that names a temporary label
/// id waits for that label's create (see `OutboxDao.nextInLine`).
@DriftAccessor(
  tables: [Outbox, Labels, Users, LabelIdRemaps, SyncState, TaskLabels],
)
final class LabelOpsDao extends DatabaseAccessor<AppDatabase>
    with _$LabelOpsDaoMixin {
  new(super.attachedDatabase);

  /// `sync_state` key: how many temporary label ids were handed out.
  static const localLabelIdsKey = 'local_label_ids';

  static final List<String> _labelKinds = [
    OutboxOperationKind.createLabel.name,
    OutboxOperationKind.updateLabel.name,
    OutboxOperationKind.deleteLabel.name,
  ];

  OutboxDao get _outbox => attachedDatabase.outboxDao;

  /// Stores [label] under the next temporary id, created by [createdBy],
  /// and queues its create, in one transaction; returns the stored label.
  /// [adopt] lets the sender take a label of that title the server already
  /// has (`findOrCreate`).
  Future<Label> queueCreate(
    NewLabel label, {
    required DateTime now,
    User? createdBy,
    bool adopt = false,
  }) => transaction(() async {
    final id = await _nextLocalId();
    final known = await _serverIdsTitled(label.title);
    if (createdBy != null) {
      await into(users)
          .insert(userRow(createdBy), mode: InsertMode.insertOrIgnore);
    }
    final stored = Label(
      id: id,
      title: label.title,
      description: label.description,
      hexColor: label.hexColor,
      createdBy: createdBy,
      created: now.toUtc(),
    );
    await into(labels).insert(labelRow(stored));
    await _outbox.queueLabelOp(
      kind: OutboxOperationKind.createLabel,
      labelId: id,
      payload: encodeLabelCreate(
        QueuedLabelCreate(label: label, adopt: adopt, known: known),
      ),
      now: now,
    );
    return stored;
  });

  /// Applies [changes] to the label here and queues them: folded into its
  /// create while that has not left the device, else behind the label's
  /// queued ops. A create from `findOrCreate` takes no edit: the server's
  /// label it may take instead would not have it, so the edit queues
  /// behind it and goes to the label it got. A temporary id whose create
  /// was answered is followed to the server id. [LabelQueueing.online] for
  /// a server label without queued ops, which changes nothing here.
  Future<(LabelQueueing, Label?)> queueUpdate(
    int localOrServerId,
    LabelChanges changes, {
    required DateTime now,
  }) => transaction(() async {
    final id = await attachedDatabase.labelsDao.resolveId(localOrServerId);
    if (id > 0 && !await hasOps(id)) return (LabelQueueing.online, null);
    final row = await _row(id);
    if (row == null) return (LabelQueueing.gone, null);
    final labelTitle = changes.title ?? row.title;
    final create = id < 0 ? await createOf(id) : null;
    final queuedCreate = create == null
        ? null
        : decodeLabelCreate(create.payload);
    if (create != null &&
        queuedCreate != null &&
        !queuedCreate.adopt &&
        OutboxDao.neverReachedServer(create)) {
      await _outbox.retake(
        create.id,
        encodeLabelCreate(await _folded(queuedCreate, changes)),
      );
    } else if (await _unsentUpdateOf(id) case final existing?) {
      await _outbox.retake(
        existing.id,
        encodeLabelChanges(
          mergeLabelChanges(decodeLabelChanges(existing.payload), changes),
          labelTitle: labelTitle,
        ),
      );
    } else {
      await _outbox.queueLabelOp(
        kind: OutboxOperationKind.updateLabel,
        labelId: id,
        payload: encodeLabelChanges(changes, labelTitle: labelTitle),
        now: now,
      );
    }
    await (update(labels)..where((l) => l.id.equals(id))).write(
      LabelsCompanion(
        title: Value.absentIfNull(changes.title),
        hexColor: Value.absentIfNull(changes.hexColor),
        description: Value.absentIfNull(changes.description),
      ),
    );
    return (LabelQueueing.queued, await attachedDatabase.labelsDao.find(id));
  });

  /// Removes the label here, from its tasks and from the queued task
  /// edits, and queues its delete: none for a create that is not on its
  /// way, which goes with it, also one sent without an answer or given up
  /// (a label such an attempt made comes back with the next sync as an
  /// ordinary label); behind the create in flight, or the label's other
  /// ops, otherwise. The delete keeps the label's title and the tasks the
  /// server has it on (see [QueuedLabelDelete]). Its queued edits go. A
  /// temporary id whose create was answered is followed to the server id.
  /// [LabelQueueing.online] for a server label without queued ops, which
  /// changes nothing here.
  Future<LabelQueueing> queueDelete(
    int localOrServerId, {
    required DateTime now,
  }) => transaction(() async {
    final id = await attachedDatabase.labelsDao.resolveId(localOrServerId);
    if (id < 0) {
      final create = await createOf(id);
      if (create == null) return LabelQueueing.gone;
      if (create.state != OutboxState.sending.name) {
        await cancelCreate(id);
        return LabelQueueing.queued;
      }
    } else if (!await hasOps(id)) {
      return LabelQueueing.online;
    }
    final queuedDelete = QueuedLabelDelete(
      title: (await _row(id))?.title ?? '',
      taskIds: await _serverCarriers(id),
    );
    await (delete(outbox)..where(
          (o) =>
              o.labelId.equals(id) &
              o.kind.equals(OutboxOperationKind.updateLabel.name) &
              o.state.equals(OutboxState.sending.name).not(),
        ))
        .go();
    if (!await _hasQueued(id, OutboxOperationKind.deleteLabel)) {
      await _outbox.queueLabelOp(
        kind: OutboxOperationKind.deleteLabel,
        labelId: id,
        payload: encodeLabelDelete(queuedDelete),
        now: now,
      );
    }
    await (delete(labels)..where((l) => l.id.equals(id))).go();
    await _outbox.forgetLabels({id});
    return LabelQueueing.queued;
  });

  /// A label created here that the server will never be asked for: its
  /// ops, its row, its place on tasks and its id in the queued task edits
  /// go.
  Future<void> cancelCreate(int localId) => transaction(() async {
    await (delete(outbox)..where((o) => o.labelId.equals(localId))).go();
    await (delete(labels)..where((l) => l.id.equals(localId))).go();
    await _outbox.forgetLabels({localId});
  });

  /// The request of the create [operationId] leaves the device at [at]; the
  /// last such time bounds the lookup for a lost answer (see
  /// [labelCreatePostedAt]).
  Future<void> markCreatePosted(
    String operationId, {
    required DateTime at,
    Set<int> alsoKnown = const {},
  }) => transaction(() async {
    final op = await _outbox.find(operationId);
    if (op == null || op.kind != OutboxOperationKind.createLabel.name) {
      return;
    }
    final payload = alsoKnown.isEmpty
        ? op.payload
        : withLabelCreateKnown(op.payload, alsoKnown);
    await (update(outbox)..where((o) => o.id.equals(operationId))).write(
      OutboxCompanion(payload: Value(withLabelCreatePostedAt(payload, at))),
    );
  });

  /// [cancelCreate] for the create [createOperationId] when a delete of its
  /// label is queued, whatever its `sent_at`: a label an unanswered attempt
  /// made comes back with the next sync as an ordinary label. False, with
  /// nothing changed, otherwise.
  Future<bool> cancelDeletedCreate(String createOperationId) =>
      transaction(() async {
        final create = await _outbox.find(createOperationId);
        final id = create?.labelId;
        if (create == null ||
            id == null ||
            create.kind != OutboxOperationKind.createLabel.name ||
            !await _hasQueued(id, OutboxOperationKind.deleteLabel)) {
          return false;
        }
        await cancelCreate(id);
        return true;
      });

  /// The server has the label as [created]: the row moves to the server id
  /// with the edits still queued on top, the tasks that carry it follow,
  /// and so do the queued ops of the label and every queued task edit that
  /// names it; the remap is recorded and the create goes. With a delete of
  /// the temporary id queued, made while the create was on its way, the
  /// label is not stored and that delete goes to the server id. A row the
  /// sync pulled meanwhile under the server id is replaced.
  ///
  /// [takenByTitle]: [created] was found by its title, a label the server
  /// had or one a lost attempt made, not this create's answer; with a delete
  /// queued it is left alone and the create goes with its label, as
  /// [cancelCreate] does.
  Future<void> completeCreate(
    String operationId,
    Label created, {
    required DateTime at,
    bool takenByTitle = false,
  }) => transaction(() async {
    final op = await _outbox.find(operationId);
    final localId = op?.labelId;
    if (op == null || localId == null) return;
    final deleting = await _hasQueued(localId, OutboxOperationKind.deleteLabel);
    if (takenByTitle && deleting) {
      await cancelCreate(localId);
      return;
    }
    final local = await attachedDatabase.labelsDao.find(localId);
    await (delete(outbox)..where((o) => o.id.equals(operationId))).go();
    await (update(outbox)..where((o) => o.labelId.equals(localId))).write(
      OutboxCompanion(labelId: Value(created.id)),
    );
    if (deleting) {
      await (delete(labels)..where((l) => l.id.equals(created.id))).go();
      await _outbox.forgetLabels({localId});
    } else {
      var stored = created.createdBy == null && local?.createdBy != null
          ? Label(
              id: created.id,
              title: created.title,
              description: created.description,
              hexColor: created.hexColor,
              createdBy: local!.createdBy,
              created: created.created,
              updated: created.updated,
            )
          : created;
      if (await queuedChangesOf(created.id) case final queued?) {
        stored = applyLabelChanges(stored, queued);
      }
      await attachedDatabase.labelsDao.storeRows([stored]);
      await customUpdate(
        'UPDATE OR IGNORE task_labels SET label_id = ? WHERE label_id = ?',
        variables: [Variable.withInt(created.id), Variable.withInt(localId)],
        updates: {taskLabels},
        updateKind: UpdateKind.update,
      );
      await _rewriteTaskEdits(localId, created.id);
    }
    await (delete(labels)..where((l) => l.id.equals(localId))).go();
    await into(labelIdRemaps).insert(
      LabelIdRemapRow(localId: localId, serverId: created.id, at: at.toUtc()),
      mode: InsertMode.insertOrReplace,
    );
  });

  /// The server stored [answer] for [op], an `updateLabel`: the op goes and
  /// the answer is stored under the edits still queued; the stored creator
  /// stays when the answer has none. For a discarded `deleteLabel`, [answer]
  /// is the label as the server still has it, and the tasks the delete
  /// kept get it back here.
  Future<void> completeUpdate(OutboxRow op, Label answer) => transaction(
    () async {
      await (delete(outbox)..where((o) => o.id.equals(op.id))).go();
      if (await _hasQueued(answer.id, OutboxOperationKind.deleteLabel)) {
        return;
      }
      final creator =
          answer.createdBy ??
          (await attachedDatabase.labelsDao.find(answer.id))?.createdBy;
      await attachedDatabase.labelsDao.upsertAll([
        Label(
          id: answer.id,
          title: answer.title,
          description: answer.description,
          hexColor: answer.hexColor,
          createdBy: creator,
          created: answer.created,
          updated: answer.updated,
        ),
      ]);
      if (op.kind == OutboxOperationKind.deleteLabel.name) {
        await _restoreOnTasks(answer.id, decodeLabelDelete(op.payload).taskIds);
      }
    },
  );

  /// The label of [op] is gone from the server, deleted by [op] or before:
  /// the op, the label's other queued ops not on their way, its row, its
  /// place on tasks and its id in the queued task edits go.
  Future<void> completeGone(OutboxRow op) => transaction(() async {
    await (delete(outbox)..where((o) => o.id.equals(op.id))).go();
    final id = op.labelId;
    if (id != null) await attachedDatabase.labelsDao.remove(id);
  });

  /// [op], a label op, failed for good. A refused create takes the edits
  /// queued behind it while it was in flight, unless it is one from
  /// `findOrCreate` (see [queueUpdate]), and goes with the label when a
  /// delete is queued behind it, as the server never had it. A failed edit
  /// folds into a newer one of the label, and a newer delete makes it
  /// moot; otherwise the op stays as a sync problem.
  Future<void> markFailed(OutboxRow op, VikunjaFailure failure) =>
      transaction(() async {
        final id = op.labelId!;
        if (op.kind == OutboxOperationKind.createLabel.name) {
          if (await _hasQueued(id, OutboxOperationKind.deleteLabel)) {
            await cancelCreate(id);
            return;
          }
          var queued = decodeLabelCreate(op.payload);
          for (final edit
              in queued.adopt ? const <OutboxRow>[] : await _updatesOf(id)) {
            queued = await _folded(queued, decodeLabelChanges(edit.payload));
            await (delete(outbox)..where((o) => o.id.equals(edit.id))).go();
          }
          await _failed(op.id, failure, payload: encodeLabelCreate(queued));
          return;
        }
        final newer =
            await (select(outbox)
                  ..where(
                    (o) =>
                        o.labelId.equals(id) &
                        o.sequence.isBiggerThanValue(op.sequence) &
                        o.state.equals(OutboxState.sending.name).not(),
                  )
                  ..orderBy([(o) => OrderingTerm.asc(o.sequence)])
                  ..limit(1))
                .getSingleOrNull();
        if (newer == null || op.kind == OutboxOperationKind.deleteLabel.name) {
          await _failed(op.id, failure);
          return;
        }
        if (newer.kind == OutboxOperationKind.updateLabel.name) {
          await _outbox.retake(
            newer.id,
            encodeLabelChanges(
              mergeLabelChanges(
                decodeLabelChanges(op.payload),
                decodeLabelChanges(newer.payload),
              ),
              labelTitle: queuedLabelTitle(newer.payload),
            ),
          );
        }
        await (delete(outbox)..where((o) => o.id.equals(op.id))).go();
      });

  /// Only a create comes with a [payload]: a refusal says the server never
  /// stored it.
  Future<void> _failed(String id, VikunjaFailure failure, {String? payload}) =>
      (update(outbox)..where((o) => o.id.equals(id))).write(
        OutboxDao.failedWith(
          failure,
          payload: payload,
          forgetSentAt: payload != null,
        ),
      );

  /// The label's create, whatever its state; null when there is none.
  Future<OutboxRow?> createOf(int labelId) =>
      (select(outbox)..where(
            (o) =>
                o.labelId.equals(labelId) &
                o.kind.equals(OutboxOperationKind.createLabel.name),
          ))
          .getSingleOrNull();

  /// Whether any op of the label is queued, whatever its state.
  Future<bool> hasOps(int labelId) async =>
      await (select(outbox)
            ..where((o) => o.labelId.equals(labelId))
            ..limit(1))
          .getSingleOrNull() !=
      null;

  /// The merge of the label's queued edits in send order; null without
  /// one.
  Future<LabelChanges?> queuedChangesOf(int labelId) async =>
      (await queuedChanges())[labelId];

  /// The merge of every label's queued edits, whatever their state, by
  /// label: what the server does not have yet.
  Future<Map<int, LabelChanges>> queuedChanges() async {
    final ops =
        await (select(outbox)
              ..where(
                (o) => o.kind.equals(OutboxOperationKind.updateLabel.name),
              )
              ..orderBy([(o) => OrderingTerm.asc(o.sequence)]))
            .get();
    final merged = <int, LabelChanges>{};
    for (final op in ops) {
      final id = op.labelId;
      if (id == null) continue;
      final changes = decodeLabelChanges(op.payload);
      merged[id] = switch (merged[id]) {
        final earlier? => mergeLabelChanges(earlier, changes),
        null => changes,
      };
    }
    return merged;
  }

  /// The labels whose delete is queued, whatever its state.
  Future<Set<int>> deletingIds() async {
    final query = selectOnly(outbox)
      ..addColumns([outbox.labelId])
      ..where(outbox.kind.equals(OutboxOperationKind.deleteLabel.name));
    return {for (final row in await query.get()) ?row.read(outbox.labelId)};
  }

  /// The labels with a queued op, whatever its state: not on the server
  /// yet, or changed here since.
  Stream<Set<int>> watchPendingIds() => watchTables({outbox}, () async {
    final query = selectOnly(outbox, distinct: true)
      ..addColumns([outbox.labelId])
      ..where(outbox.labelId.isNotNull());
    return {for (final row in await query.get()) ?row.read(outbox.labelId)};
  });

  /// Whether [op], a task update, names a label created here whose create
  /// has not been answered; it waits for that create.
  Future<bool> waitsForCreate(OutboxRow op) async {
    if (op.kind != OutboxOperationKind.updateTask.name ||
        !op.payload.contains('"labels"')) {
      return false;
    }
    return (await resolveLabels(
      decodeTaskChanges(op.payload),
      taskId: op.taskId,
    )).waits;
  }

  /// [changes], of the task [taskId], with every temporary label id
  /// followed to the server id once its create was answered; one whose
  /// create is gone (discarded or cancelled) is left out, and an id both
  /// added and removed after that is an add while the task carries the
  /// label, else a removal (see [withLabelIdsMapped]). `waits` while a
  /// label's create is still queued; that id stays.
  Future<({TaskChanges changes, bool waits})> resolveLabels(
    TaskChanges changes, {
    required int taskId,
  }) async {
    final labels = changes.labels;
    if (labels == null ||
        (labels.added.every((id) => id > 0) &&
            labels.removed.every((id) => id > 0))) {
      return (changes: changes, waits: false);
    }
    final mapping = <int, int>{};
    final dropped = <int>{};
    var waits = false;
    for (final id in {...labels.added, ...labels.removed}) {
      if (id > 0) continue;
      final serverId = await attachedDatabase.labelsDao.resolveId(id);
      if (serverId > 0) {
        mapping[id] = serverId;
      } else if (await createOf(id) != null) {
        waits = true;
      } else {
        dropped.add(id);
      }
    }
    return (
      changes: withLabelIdsMapped(
        withoutLabels(changes, dropped),
        mapping,
        carried: mapping.isEmpty
            ? const {}
            : await _labelsOf(
                await attachedDatabase.tasksDao.resolveId(taskId),
              ),
      ),
      waits: waits,
    );
  }

  /// Every queued task edit that names the label [from] names [to]
  /// instead; the tasks' `pending_changes` follow.
  Future<void> _rewriteTaskEdits(int from, int to) async {
    final touched = <int>{};
    for (final op in await _taskEditsNaming(from)) {
      final rewritten = withLabelIdsMapped(decodeTaskChanges(op.payload), {
        from: to,
      }, carried: await _labelsOf(op.taskId));
      await _outbox.storeRewritten(op, rewritten, retake: false);
      touched.add(op.taskId);
    }
    for (final taskId in touched) {
      await _outbox.refreshPendingChanges(taskId);
    }
  }

  /// The queued task edits that add or remove the label, oldest first.
  Future<List<OutboxRow>> _taskEditsNaming(int labelId) async {
    final ops =
        await (select(outbox)
              ..where(
                (o) =>
                    o.kind.equals(OutboxOperationKind.updateTask.name) &
                    o.payload.like('%"labels"%'),
              )
              ..orderBy([(o) => OrderingTerm.asc(o.sequence)]))
            .get();
    return [
      for (final op in ops)
        if (decodeTaskChanges(op.payload).labels case final labels?
            when labels.added.contains(labelId) ||
                labels.removed.contains(labelId))
          op,
    ];
  }

  /// The tasks the server has the label on, as far as this device knows:
  /// those that carry it here, but not through a queued add the delete
  /// drops, and those with a queued removal it drops. None for a label
  /// created here, whose adds all wait for its create.
  Future<Set<int>> _serverCarriers(int labelId) async {
    if (labelId < 0) return {};
    final carriers = await _tasksCarrying(labelId);
    for (final op in await _taskEditsNaming(labelId)) {
      if (op.state == OutboxState.sending.name) continue;
      final labels = decodeTaskChanges(op.payload).labels!;
      if (labels.added.contains(labelId)) carriers.remove(op.taskId);
      if (labels.removed.contains(labelId)) carriers.add(op.taskId);
    }
    return carriers;
  }

  /// The label's queued edits not on their way, oldest first.
  Future<List<OutboxRow>> _updatesOf(int labelId) =>
      (select(outbox)
            ..where(
              (o) =>
                  o.labelId.equals(labelId) &
                  o.kind.equals(OutboxOperationKind.updateLabel.name) &
                  o.state.equals(OutboxState.sending.name).not(),
            )
            ..orderBy([(o) => OrderingTerm.asc(o.sequence)]))
          .get();

  /// The newest queued edit of the label not on its way.
  Future<OutboxRow?> _unsentUpdateOf(int labelId) async =>
      (await _updatesOf(labelId)).lastOrNull;

  Future<bool> _hasQueued(int labelId, OutboxOperationKind kind) async =>
      await (select(outbox)
            ..where((o) => o.labelId.equals(labelId) & o.kind.equals(kind.name))
            ..limit(1))
          .getSingleOrNull() !=
      null;

  /// Every label op of [labelIds] not on its way goes: the labels are gone.
  Future<void> removeOpsOf(Set<int> labelIds) =>
      (delete(outbox)..where(
            (o) =>
                o.labelId.isIn(labelIds) &
                o.kind.isIn(_labelKinds) &
                o.state.equals(OutboxState.sending.name).not(),
          ))
          .go();

  Future<LabelRow?> _row(int id) =>
      (select(labels)..where((l) => l.id.equals(id))).getSingleOrNull();

  /// [create] with [changes] folded in; a new title adds the labels the
  /// device has of exactly that title to its `known`.
  Future<QueuedLabelCreate> _folded(
    QueuedLabelCreate create,
    LabelChanges changes,
  ) async {
    final title = changes.title;
    return create.withChanges(
      changes,
      alsoKnown: title == null || title == create.label.title
          ? const {}
          : await _serverIdsTitled(title),
    );
  }

  /// The labels the task carries here.
  Future<Set<int>> _labelsOf(int taskId) async {
    final query = selectOnly(taskLabels)
      ..addColumns([taskLabels.labelId])
      ..where(taskLabels.taskId.equals(taskId));
    return {for (final row in await query.get()) row.read(taskLabels.labelId)!};
  }

  /// The tasks that carry the label here.
  Future<Set<int>> _tasksCarrying(int labelId) async {
    final query = selectOnly(taskLabels)
      ..addColumns([taskLabels.taskId])
      ..where(taskLabels.labelId.equals(labelId));
    return {for (final row in await query.get()) row.read(taskLabels.taskId)!};
  }

  /// The label goes back on those of [taskIds] this device still has, each
  /// followed to its server id.
  Future<void> _restoreOnTasks(int labelId, Set<int> taskIds) async {
    if (taskIds.isEmpty) return;
    final resolved = {
      for (final id in taskIds) await attachedDatabase.tasksDao.resolveId(id),
    };
    final tasks = attachedDatabase.tasks;
    final query = selectOnly(tasks)
      ..addColumns([tasks.id])
      ..where(tasks.id.isIn(resolved));
    final present = [for (final row in await query.get()) row.read(tasks.id)!];
    await batch(
      (b) => b.insertAll(taskLabels, [
        for (final taskId in present)
          TaskLabelsCompanion.insert(taskId: taskId, labelId: labelId),
      ], mode: InsertMode.insertOrIgnore),
    );
  }

  Future<Set<int>> _serverIdsTitled(String title) async {
    final query = selectOnly(labels)
      ..addColumns([labels.id])
      ..where(labels.title.equals(title) & labels.id.isBiggerThanValue(0));
    return {for (final row in await query.get()) row.read(labels.id)!};
  }

  Future<int> _nextLocalId() async {
    final row = await (select(
      syncState,
    )..where((s) => s.key.equals(localLabelIdsKey))).getSingleOrNull();
    final next = (int.tryParse(row?.value ?? '') ?? 0) + 1;
    await into(syncState).insert(
      SyncStateRow(key: localLabelIdsKey, value: '$next'),
      mode: InsertMode.insertOrReplace,
    );
    return -next;
  }
}
