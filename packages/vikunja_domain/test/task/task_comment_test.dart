import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

const _author = User(id: 3, username: 'jane', name: 'Jane');
const _bob = User(id: 4, username: 'bob');

TaskComment _comment({
  DateTime? created,
  DateTime? updated,
  String? html,
  Reactions reactions = const {},
}) => TaskComment(
  id: 7,
  html: html ?? '<p>hi</p>',
  author: _author,
  created: created,
  updated: updated,
  reactions: reactions,
);

void main() {
  final created = DateTime.utc(2026, 10, 19, 6, 22, 57);

  group('isEdited', () {
    test('updated more than three seconds after created', () {
      expect(
        _comment(
          created: created,
          updated: created.add(const Duration(seconds: 3, milliseconds: 1)),
        ).isEdited,
        isTrue,
      );
      expect(
        _comment(
          created: created,
          updated: created.add(const Duration(days: 2)),
        ).isEdited,
        isTrue,
      );
    });

    // The create answer's times are nanoseconds apart and a read keeps
    // whole seconds, so a fresh comment can read a second apart.
    test('not within three seconds', () {
      for (final apart in const [
        Duration.zero,
        Duration(microseconds: 1),
        Duration(seconds: 1),
        Duration(seconds: 3),
      ]) {
        expect(
          _comment(created: created, updated: created.add(apart)).isEdited,
          isFalse,
          reason: '$apart',
        );
      }
    });

    test('the same time in any zone', () {
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

  group('equality', () {
    test('by id, text, author, times and reactions', () {
      expect(_comment(created: created), _comment(created: created));
      expect(
        _comment(created: created).hashCode,
        _comment(created: created).hashCode,
      );
      expect(_comment(html: '<p>other</p>'), isNot(_comment()));
      expect(_comment(created: created), isNot(_comment()));
      expect(_comment(updated: created), isNot(_comment()));
      expect(
        _comment(
          reactions: const {
            '👍': [_author],
          },
        ),
        isNot(_comment()),
      );
    });

    test('reactions compare by value and users, not by key order', () {
      final a = _comment(
        reactions: const {
          '👍': [_author, _bob],
          '🎉': [_bob],
        },
      );
      final b = _comment(
        reactions: const {
          '🎉': [_bob],
          '👍': [_author, _bob],
        },
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          _comment(
            reactions: const {
              '👍': [_bob, _author],
              '🎉': [_bob],
            },
          ),
        ),
      );
    });
  });

  group('copyWith', () {
    final comment = _comment(
      created: created,
      updated: created,
      reactions: const {
        '👍': [_bob],
      },
    );

    test('keeps what is left out', () {
      final copy = comment.copyWith();

      expect(copy, comment);
      expect(copy.id, 7);
    });

    test('replaces each field', () {
      final later = created.add(const Duration(minutes: 1));

      expect(comment.copyWith(html: '<p>new</p>').html, '<p>new</p>');
      expect(comment.copyWith(author: _bob).author, _bob);
      expect(comment.copyWith(created: later).created, later);
      expect(comment.copyWith(updated: later).updated, later);
      expect(comment.copyWith(reactions: const {}).reactions, isEmpty);
    });

    test('clears the times passed as null', () {
      final copy = comment.copyWith(created: null, updated: null);

      expect(copy.created, isNull);
      expect(copy.updated, isNull);
    });
  });
}
