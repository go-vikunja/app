import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/storage/comment_drafts.dart';
import 'package:vikunja_mobile/features/tasks/application/comment_sends.dart';

CommentSend _send(String text) => CommentSend(
  CommentComposerDraft(text: text),
  Completer<TaskComment>().future,
);

void main() {
  test('a send is found by its account and task until it ends', () {
    final sends = CommentSends();
    final send = _send('Looks good');

    sends.start('a', 4, send);

    expect(sends.of('a', 4), same(send));
    expect(sends.of('b', 4), isNull);
    expect(sends.of('a', 5), isNull);

    sends.end('a', 4, send);
    expect(sends.of('a', 4), isNull);
  });

  test('the end of an earlier send leaves a later one of the same task', () {
    final sends = CommentSends();
    final earlier = _send('First');
    final later = _send('Second');

    sends
      ..start('a', 4, earlier)
      ..start('a', 4, later)
      ..end('a', 4, earlier);

    expect(sends.of('a', 4), same(later));
  });
}
