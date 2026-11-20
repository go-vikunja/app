import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';

void main() {
  test('a create of a task or a label and an upload may leave something on '
      'the server without an answer; an edit or a delete does not', () {
    expect(
      {
        for (final kind in OutboxOperationKind.values)
          kind: kind.createsOnServer,
      },
      {
        OutboxOperationKind.createTask: true,
        OutboxOperationKind.updateTask: false,
        OutboxOperationKind.deleteTask: false,
        OutboxOperationKind.uploadAttachment: true,
        OutboxOperationKind.createLabel: true,
        OutboxOperationKind.updateLabel: false,
        OutboxOperationKind.deleteLabel: false,
      },
    );
    expect(OutboxDao.createKinds, {
      'createTask',
      'uploadAttachment',
      'createLabel',
    });
  });
}
