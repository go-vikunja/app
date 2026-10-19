import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

const _author = User(id: 3, username: 'jane', name: 'Jane');

TaskComment _comment({DateTime? created, DateTime? updated, String? html}) =>
    TaskComment(
      id: 7,
      html: html ?? '<p>hi</p>',
      author: _author,
      created: created,
      updated: updated,
    );

void main() {
  final created = DateTime.utc(2026, 10, 19, 6, 22, 57);

  group('isEdited, as the web decides it', () {
    test('both times known and different', () {
      expect(
        _comment(
          created: created,
          updated: created.add(const Duration(seconds: 1)),
        ).isEdited,
        isTrue,
      );
    });

    test('the same time, in any zone', () {
      expect(_comment(created: created, updated: created).isEdited, isFalse);
      expect(
        _comment(created: created, updated: created.toLocal()).isEdited,
        isFalse,
      );
    });

    test('a missing time', () {
      expect(_comment(created: created).isEdited, isFalse);
      expect(_comment(updated: created).isEdited, isFalse);
      expect(_comment().isEdited, isFalse);
    });
  });

  test('no reactions by default', () {
    expect(_comment().reactions, isEmpty);
  });

  test('equal by id, text, author and times', () {
    expect(_comment(created: created), _comment(created: created));
    expect(
      _comment(created: created).hashCode,
      _comment(created: created).hashCode,
    );
    expect(_comment(html: '<p>other</p>'), isNot(_comment()));
    expect(_comment(created: created), isNot(_comment()));
  });
}
