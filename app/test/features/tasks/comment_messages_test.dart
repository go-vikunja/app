import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comment_messages.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comments_controller.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comments_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/details_notice.dart';

import '../../helpers/pump_app.dart';

void main() {
  test('a task gone, in the trash or in a trashed project is not found', () {
    for (final code in [4002, 4040, 3018, 3001]) {
      for (final write in CommentWrite.values) {
        expect(
          commentFailureText(en, NotFound(code: code), write),
          en.taskOpenNotFound,
          reason: '$code $write',
        );
      }
    }
  });

  test('a comment that is gone is not the task', () {
    expect(
      commentFailureText(en, const NotFound(code: 4015), CommentWrite.save),
      en.commentFailedGone,
    );
  });

  test('stored comments that stand in are announced with the reason the '
      'read failed', () {
    final now = DateTime.utc(2026, 11, 19, 12);
    final storedAt = now.subtract(const Duration(hours: 2));
    final when = storedWhen(en, storedAt, now: now);
    String? announced(Object failure) => commentsResultAnnouncement(
      en,
      before: CommentsState(loading: true, storedAt: storedAt),
      after: CommentsState(shown: true, failure: failure, storedAt: storedAt),
      now: now,
    );

    expect(
      announced(const NetworkFailure(NetworkProblem.unreachable)),
      en.commentsStored(when),
    );
    expect(announced(const ServerFailure(502)), en.commentsStoredFailed(when));
  });
}
