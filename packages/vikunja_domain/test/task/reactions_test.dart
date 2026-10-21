import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

const _alice = User(id: 1, username: 'alice');
const _bob = User(id: 2, username: 'bob');

void main() {
  test('the entities are named by their route segment', () {
    expect(ReactionEntity.task.wireName, 'tasks');
    expect(ReactionEntity.comment.wireName, 'comments');
  });

  test('the server takes up to 20 code points', () {
    expect(maxReactionLength, 20);
  });

  group('reactionsEqual and reactionsHash', () {
    test('empty maps are equal', () {
      expect(reactionsEqual(const {}, const {}), isTrue);
      expect(reactionsHash(const {}), reactionsHash(<String, List<User>>{}));
    });

    test('the order of the values does not count', () {
      const a = {
        '👍': [_alice],
        '❤️': [_bob],
      };
      const b = {
        '❤️': [_bob],
        '👍': [_alice],
      };

      expect(reactionsEqual(a, b), isTrue);
      expect(reactionsHash(a), reactionsHash(b));
    });

    test('values, users and their order count', () {
      const base = {
        '👍': [_alice, _bob],
      };

      expect(
        reactionsEqual(base, const {
          '👍': [_bob, _alice],
        }),
        isFalse,
      );
      expect(
        reactionsEqual(base, const {
          '👍': [_alice],
        }),
        isFalse,
      );
      expect(
        reactionsEqual(base, const {
          '👍🏽': [_alice, _bob],
        }),
        isFalse,
      );
      expect(
        reactionsEqual(base, const {
          '👍': [_alice, _bob],
          '🎉': [_alice],
        }),
        isFalse,
      );
      expect(reactionsEqual(base, const {}), isFalse);
    });
  });
}
