import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/features/home/presentation/sync_problem_message.dart';

import '../../helpers/pump_app.dart';

void main() {
  SyncProblem problem(
    VikunjaFailure failure, {
    OutboxOperationKind kind = OutboxOperationKind.updateTask,
    TaskChanges? changes,
    String? fileName,
  }) => SyncProblem(
    operationId: 'op',
    kind: kind,
    taskId: 1,
    taskTitle: 'Pay the bill',
    failure: failure,
    failedAt: DateTime.utc(2026, 10, 10, 12),
    changes: changes,
    fileName: fileName,
  );

  test('names what failed by the kind of change', () {
    expect(
      describeSyncProblem(en, problem(const Forbidden(code: 7003))),
      '${en.syncProblemUpdateFailed} ${en.syncProblemForbidden}',
    );
    expect(
      describeSyncProblem(
        en,
        problem(
          const Forbidden(code: 7003),
          kind: OutboxOperationKind.deleteTask,
        ),
      ),
      '${en.syncProblemDeleteFailed} ${en.syncProblemForbidden}',
    );
  });

  test('names a failed change of a label and says why', () {
    String describe(OutboxOperationKind kind, VikunjaFailure failure) =>
        describeSyncProblem(en, problem(failure, kind: kind));
    const create = OutboxOperationKind.createLabel;
    const update = OutboxOperationKind.updateLabel;
    const delete = OutboxOperationKind.deleteLabel;

    expect(
      describe(create, const ValidationFailed(message: 'invalid')),
      '${en.syncProblemLabelCreateFailed} ${en.labelsInvalid}',
    );
    expect(
      describe(update, const Forbidden()),
      '${en.syncProblemLabelUpdateFailed} ${en.labelsNotCreator}',
    );
    expect(
      describe(delete, const Forbidden()),
      '${en.syncProblemLabelDeleteFailed} ${en.labelsNotCreator}',
    );
    expect(
      describe(create, const Forbidden()),
      '${en.syncProblemLabelCreateFailed} ${en.syncProblemRejected}',
    );
    expect(
      describe(update, const NotFound(code: 8002)),
      '${en.syncProblemLabelUpdateFailed} ${en.labelsGone}',
    );
    expect(
      describe(delete, const NotFound()),
      '${en.syncProblemLabelDeleteFailed} ${en.syncProblemUnexpected}',
    );
    expect(
      describe(update, const DomainError(400, code: 2002)),
      '${en.syncProblemLabelUpdateFailed} ${en.labelsInvalid}',
    );
    expect(
      describe(create, const DomainError(400, code: 8001)),
      '${en.syncProblemLabelCreateFailed} ${en.syncProblemRejected}',
    );
    expect(
      describe(delete, const ServerFailure(500)),
      '${en.syncProblemLabelDeleteFailed} ${en.syncProblemServerKeptFailing}',
    );
    expect(
      describe(create, const NetworkFailure(NetworkProblem.timeout)),
      '${en.syncProblemLabelCreateFailed} ${en.syncProblemUnexpected}',
    );
  });

  test('a description also changed on the web says so', () {
    expect(
      describeSyncProblem(
        en,
        problem(
          const DescriptionConflict(),
          changes: const TaskChanges(description: '<p>Mine</p>'),
        ),
      ),
      '${en.syncProblemUpdateFailed} ${en.syncProblemDescriptionConflict}',
    );
  });

  test('explains each permanent failure the server can answer with', () {
    String describe(VikunjaFailure failure) =>
        describeSyncProblem(en, problem(failure));
    expect(
      describe(const NotFound(code: 3001)),
      endsWith(en.syncProblemProjectMissing),
    );
    expect(
      describe(const NotFound(code: 4002)),
      endsWith(en.syncProblemTaskMissing),
    );
    expect(
      describe(const NotFound(code: 8002)),
      endsWith(en.syncProblemLabelMissing),
    );
    expect(
      describe(const NotFound(code: 1005)),
      endsWith(en.syncProblemUserMissing),
    );
    expect(
      describe(const DomainError(412, code: 3008)),
      endsWith(en.syncProblemProjectArchived),
    );
    for (final code in [4002, 4040, 3018]) {
      expect(
        describe(RelatedTaskMissing(7, code: code)),
        endsWith(en.syncProblemRelatedTaskMissing),
        reason: '$code',
      );
    }
    expect(
      describe(const DomainError(409, code: 4023)),
      endsWith(en.syncProblemRelationCycle),
    );
    expect(
      describe(const DomainError(400, code: 4010)),
      endsWith(en.syncProblemRelationToItself),
    );
    expect(
      describe(const DomainError(400, code: 4029)),
      endsWith(en.syncProblemRepeatTooLong),
    );
    expect(
      describe(const DomainError(400, code: 4007)),
      endsWith(en.syncProblemRejected),
    );
    expect(
      describe(const ValidationFailed(code: 4001, message: 'title empty')),
      endsWith(en.syncProblemRejected),
    );
    expect(
      describe(const UnexpectedResponse(418)),
      endsWith(en.syncProblemUnexpected),
    );
    expect(
      describe(const UnexpectedResponse(200, message: 'task without id')),
      endsWith(en.syncProblemUnexpected),
    );
  });

  test('an op the outbox gave up on says the server kept failing, or that a '
      "web server's 404 was unexpected", () {
    expect(
      describeSyncProblem(en, problem(const ServerFailure(502))),
      '${en.syncProblemUpdateFailed} ${en.syncProblemServerKeptFailing}',
    );
    expect(
      describeSyncProblem(
        en,
        problem(const ServerFailure(500), kind: OutboxOperationKind.createTask),
      ),
      '${en.syncProblemCreateFailed} ${en.syncProblemServerKeptFailing}',
    );
    expect(
      describeSyncProblem(en, problem(const NotFound())),
      '${en.syncProblemUpdateFailed} ${en.syncProblemUnexpected}',
    );
  });

  test('explains a move the board refused', () {
    String describe(VikunjaFailure failure) =>
        describeSyncProblem(en, problem(failure));
    expect(
      describe(const DomainError(412, code: 10004)),
      endsWith(en.syncProblemColumnFull),
    );
    expect(
      describe(const NotFound(code: 10001)),
      endsWith(en.syncProblemColumnMissing),
    );
    expect(
      describe(const DomainError(400, code: 10002)),
      endsWith(en.syncProblemColumnMissing),
    );
    expect(
      describe(const NotFound(code: 3014)),
      endsWith(en.syncProblemColumnMissing),
    );
    expect(describe(const Forbidden()), endsWith(en.syncProblemForbidden));
    expect(
      describeSyncProblem(de, problem(const DomainError(412, code: 10004))),
      '${de.syncProblemUpdateFailed} Diese Spalte ist voll.',
    );
  });

  test('explains a reorder the list refused, where only the position '
      'write can have been refused', () {
    const reorder = TaskChanges(positions: {70: 0.5});
    String describe(VikunjaFailure failure, TaskChanges changes) =>
        describeSyncProblem(en, problem(failure, changes: changes));

    expect(
      describe(const Forbidden(), reorder),
      endsWith(en.syncProblemListNotReorderable),
    );
    expect(
      describe(const NotFound(code: 3014), reorder),
      endsWith(en.syncProblemListMissing),
    );
    expect(
      describe(
        const NotFound(code: 3014),
        reorder.merge(const TaskChanges(title: 'Renamed')),
      ),
      endsWith(en.syncProblemListMissing),
    );
    expect(
      describe(
        const Forbidden(),
        reorder.merge(const TaskChanges(title: 'Renamed')),
      ),
      endsWith(en.syncProblemForbidden),
    );
    expect(
      describe(
        const NotFound(code: 3014),
        reorder.merge(
          const TaskChanges(kanban: {80: BucketPlacement(bucketId: 2)}),
        ),
      ),
      endsWith(en.syncProblemColumnMissing),
    );
    expect(
      describe(const DomainError(412, code: 3008), reorder),
      endsWith(en.syncProblemProjectArchived),
    );
    expect(
      describeSyncProblem(de, problem(const Forbidden(), changes: reorder)),
      '${de.syncProblemUpdateFailed} Diese Liste kann nicht umsortiert '
      'werden.',
    );
  });

  test('a task or project in the bin on the server says so', () {
    for (final l10n in [en, de]) {
      for (final kind in [
        OutboxOperationKind.updateTask,
        OutboxOperationKind.deleteTask,
      ]) {
        expect(
          describeSyncProblem(
            l10n,
            problem(const NotFound(code: 4040), kind: kind),
          ),
          endsWith(' ${l10n.syncProblemTaskInTrash}'),
          reason: '${l10n.localeName} $kind',
        );
        expect(
          describeSyncProblem(
            l10n,
            problem(const NotFound(code: 3018), kind: kind),
          ),
          endsWith(' ${l10n.syncProblemProjectInTrash}'),
          reason: '${l10n.localeName} $kind',
        );
      }
    }
    expect(
      describeSyncProblem(
        en,
        problem(
          const NotFound(
            code: 4040,
            trash: TrashDetails(id: 1, canRestore: true),
          ),
        ),
      ),
      '${en.syncProblemUpdateFailed} ${en.syncProblemTaskInTrash}',
    );
    expect(
      describeSyncProblem(en, problem(const NotFound(code: 3018))),
      '${en.syncProblemUpdateFailed} ${en.syncProblemProjectInTrash}',
    );
  });

  test('is in German', () {
    expect(
      describeSyncProblem(de, problem(const DomainError(412, code: 3008))),
      '${de.syncProblemUpdateFailed} ${de.syncProblemProjectArchived}',
    );
  });

  test('a refused upload names the file and why', () {
    String describe(VikunjaFailure failure, [AppLocalizations? l10n]) =>
        describeSyncProblem(
          l10n ?? en,
          problem(
            failure,
            kind: OutboxOperationKind.uploadAttachment,
            fileName: 'scan.pdf',
          ),
        );
    final what = en.syncProblemUploadFailed('scan.pdf');
    expect(
      describe(const FileTooLarge(code: 4012)),
      '$what ${en.syncProblemUploadTooLarge}',
    );
    expect(
      describe(const DomainError(412, code: 3008)),
      '$what ${en.syncProblemProjectArchived}',
    );
    expect(
      describe(const NotFound(code: 4002)),
      '$what ${en.syncProblemTaskMissing}',
    );
    expect(
      describe(const NotFound(code: 4040)),
      '$what ${en.syncProblemTaskInTrash}',
    );
    expect(
      describe(const NotFound(code: 3018)),
      '$what ${en.syncProblemProjectInTrash}',
    );
    expect(
      describe(const NotFound()),
      '$what ${en.syncProblemAttachmentsDisabled}',
    );
    expect(
      describe(const Forbidden(code: 1)),
      '$what ${en.syncProblemUploadForbidden}',
    );
    expect(
      describe(const ServerFailure(500)),
      '$what ${en.syncProblemServerKeptFailing}',
    );
    expect(
      describe(const NetworkFailure(NetworkProblem.timeout)),
      '$what ${en.syncProblemUploadTimedOut}',
    );
    expect(
      describe(const FileTooLarge(code: 4035), de),
      '${de.syncProblemUploadFailed('scan.pdf')} '
      '${de.syncProblemUploadTooLarge}',
    );
  });
}
