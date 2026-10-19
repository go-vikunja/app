import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  test('the defaults: nothing attached, no cover, no reactions, no comments, '
      'read, not followed', () {
    const details = TaskDetails();

    expect(details.attachments, isEmpty);
    expect(details.coverImageAttachmentId, 0);
    expect(details.reactions, isEmpty);
    expect(details.commentCount, 0);
    expect(details.isUnread, isFalse);
    expect(details.subscription, isNull);
  });

  group('attachments', () {
    const attachment = TaskAttachment(
      id: 14,
      taskId: 17,
      name: 'pic.png',
      mime: 'image/png',
      size: 82185,
    );

    test('the file fields default to unknown', () {
      const bare = TaskAttachment(id: 1, taskId: 2, name: 'a');

      expect(bare.mime, isEmpty);
      expect(bare.size, 0);
      expect(bare.created, isNull);
      expect(bare.createdBy, isNull);
    });

    test('equal by id, task, name, mime and size', () {
      expect(
        attachment,
        TaskAttachment(
          id: 14,
          taskId: 17,
          name: 'pic.png',
          mime: 'image/png',
          size: 82185,
          created: DateTime.utc(2026),
          createdBy: const User(id: 3, username: 'a'),
        ),
      );
      expect(
        attachment.hashCode,
        const TaskAttachment(
          id: 14,
          taskId: 17,
          name: 'pic.png',
          mime: 'image/png',
          size: 82185,
        ).hashCode,
      );
      expect(
        attachment,
        isNot(
          const TaskAttachment(
            id: 14,
            taskId: 17,
            name: 'pic.png',
            mime: 'text/plain',
            size: 82185,
          ),
        ),
      );
    });
  });
}
