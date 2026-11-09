import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comment_messages.dart';

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
}
