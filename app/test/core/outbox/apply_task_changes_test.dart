import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/outbox/apply_task_changes.dart';

void main() {
  test('a cover change survives every rewrite of queued changes', () {
    const changes = TaskChanges(
      title: 'Ship',
      description: '<p>a</p>',
      descriptionBase: '',
      labels: IdSetChange(added: {1}),
      coverImageAttachmentId: 0,
    );
    for (final rewritten in [
      changesAfterCreate(changes),
      withoutLabels(changes, {1}),
      withoutPlacements(changes),
      withoutRelatedTasks(changes, {9}),
      withDescriptionBase(changes, '<p>web</p>'),
      withoutDescription(changes),
    ]) {
      expect(rewritten.coverImageAttachmentId, 0);
    }
  });
}
