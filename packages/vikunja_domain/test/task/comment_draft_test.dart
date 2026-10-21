import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  test('equal by its HTML', () {
    expect(const CommentDraft('<p>a</p>'), const CommentDraft('<p>a</p>'));
    expect(
      const CommentDraft('<p>a</p>').hashCode,
      const CommentDraft('<p>a</p>').hashCode,
    );
    expect(
      const CommentDraft('<p>a</p>'),
      isNot(const CommentDraft('<p>b</p>')),
    );
  });

  test('toString does not show the text', () {
    expect(
      const CommentDraft('<p>secret</p>').toString(),
      isNot(contains('secret')),
    );
  });
}
