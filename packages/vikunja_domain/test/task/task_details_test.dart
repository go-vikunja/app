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
    expect(details.maxPermission, isNull);
  });

  group('copyWith', () {
    const subscription = Subscription(
      entity: SubscriptionEntity.task,
      entityId: 4,
    );
    const details = TaskDetails(
      attachments: [TaskAttachment(id: 1, taskId: 4, name: 'a')],
      coverImageAttachmentId: 1,
      reactions: {
        '👍': [User(id: 2, username: 'b')],
      },
      commentCount: 3,
      isUnread: true,
      subscription: subscription,
      maxPermission: Permission.write,
    );

    test('keeps every field that is left out', () {
      final copy = details.copyWith();

      expect(copy.attachments, details.attachments);
      expect(copy.coverImageAttachmentId, 1);
      expect(copy.reactions, details.reactions);
      expect(copy.commentCount, 3);
      expect(copy.isUnread, isTrue);
      expect(copy.subscription, subscription);
      expect(copy.maxPermission, Permission.write);
    });

    test('replaces each field', () {
      expect(details.copyWith(attachments: const []).attachments, isEmpty);
      expect(
        details.copyWith(coverImageAttachmentId: 0).coverImageAttachmentId,
        0,
      );
      expect(details.copyWith(reactions: const {}).reactions, isEmpty);
      expect(details.copyWith(commentCount: 4).commentCount, 4);
      expect(details.copyWith(isUnread: false).isUnread, isFalse);
      expect(
        details.copyWith(maxPermission: Permission.read).maxPermission,
        Permission.read,
      );
    });

    test('clears the subscription and the permission passed as null', () {
      final copy = details.copyWith(subscription: null, maxPermission: null);

      expect(copy.subscription, isNull);
      expect(copy.maxPermission, isNull);
    });
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
