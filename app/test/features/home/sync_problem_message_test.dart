import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/features/home/presentation/sync_problem_message.dart';

import '../../helpers/pump_app.dart';

void main() {
  SyncProblem problem(
    VikunjaFailure failure, {
    OutboxOperationKind kind = OutboxOperationKind.updateTask,
  }) => SyncProblem(
    operationId: 'op',
    kind: kind,
    taskId: 1,
    taskTitle: 'Pay the bill',
    failure: failure,
    failedAt: DateTime.utc(2026, 10, 10, 12),
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

  test('is in German', () {
    expect(
      describeSyncProblem(de, problem(const DomainError(412, code: 3008))),
      '${de.syncProblemUpdateFailed} ${de.syncProblemProjectArchived}',
    );
  });
}
