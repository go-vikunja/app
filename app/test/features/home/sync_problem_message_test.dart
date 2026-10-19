import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/features/home/presentation/sync_problem_message.dart';

import '../../helpers/pump_app.dart';

void main() {
  SyncProblem problem(
    VikunjaFailure failure, {
    OutboxOperationKind kind = OutboxOperationKind.updateTask,
    TaskChanges? changes,
  }) => SyncProblem(
    operationId: 'op',
    kind: kind,
    taskId: 1,
    taskTitle: 'Pay the bill',
    failure: failure,
    failedAt: DateTime.utc(2026, 10, 10, 12),
    changes: changes,
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
    expect(
      describe(const RelatedTaskMissing(7)),
      endsWith(en.syncProblemRelatedTaskMissing),
    );
    expect(
      describe(const DomainError(409, code: 4023)),
      endsWith(en.syncProblemRelationCycle),
    );
    expect(
      describe(const DomainError(400, code: 4010)),
      endsWith(en.syncProblemRelationToItself),
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
      describe(const ServerFailure(500)),
      endsWith(en.syncProblemUnexpected),
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

  test('is in German', () {
    expect(
      describeSyncProblem(de, problem(const DomainError(412, code: 3008))),
      '${de.syncProblemUpdateFailed} ${de.syncProblemProjectArchived}',
    );
  });
}
