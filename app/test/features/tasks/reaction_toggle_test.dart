import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/tasks/application/reaction_toggle.dart';

void main() {
  const me = User(id: 1, username: 'me');
  const anna = User(id: 2, username: 'anna');
  const ben = User(id: 3, username: 'ben');

  List<String> order(Reactions reactions) => [
    for (final MapEntry(:key, :value) in reactions.entries)
      '$key:${value.map((user) => user.username).join(',')}',
  ];

  test('adding leaves the other values, mine among them, in place', () {
    final reactions = <String, List<User>>{
      '🎉': [me, anna],
      '👍': [anna],
      '🚀': [me],
    };

    expect(order(toggledReaction(reactions, '👍', me: me, add: true)), [
      '🎉:me,anna',
      '👍:anna,me',
      '🚀:me',
    ]);
  });

  test('a new value goes last', () {
    final reactions = <String, List<User>>{
      '👍': [anna],
    };

    expect(order(toggledReaction(reactions, '👀', me: me, add: true)), [
      '👍:anna',
      '👀:me',
    ]);
  });

  test('removing takes me out of that value alone; an empty one goes', () {
    final reactions = <String, List<User>>{
      '🎉': [anna, me, ben],
      '👍': [me],
      '🚀': [me],
    };

    expect(order(toggledReaction(reactions, '🎉', me: me, add: false)), [
      '🎉:anna,ben',
      '👍:me',
      '🚀:me',
    ]);
    expect(order(toggledReaction(reactions, '👍', me: me, add: false)), [
      '🎉:anna,me,ben',
      '🚀:me',
    ]);
  });

  test('what is already so changes nothing', () {
    final reactions = <String, List<User>>{
      '👍': [anna, me],
    };

    expect(
      toggledReaction(reactions, '👍', me: me, add: true),
      same(reactions),
    );
    expect(
      toggledReaction(reactions, '🎉', me: me, add: false),
      same(reactions),
    );
  });

  test('reactedWith', () {
    final reactions = <String, List<User>>{
      '👍': [anna, me],
    };

    expect(reactedWith(reactions, '👍', me.id), isTrue);
    expect(reactedWith(reactions, '👍', ben.id), isFalse);
    expect(reactedWith(reactions, '🎉', me.id), isFalse);
  });
}
