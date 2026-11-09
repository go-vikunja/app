import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/text/task_title_limit.dart';

void main() {
  const max = Task.maxTitleLength;

  test('a title that fits is kept as it is', () {
    final exactly = 'a' * max;

    expect(cutTaskTitle('Buy milk'), (title: 'Buy milk', rest: ''));
    expect(cutTaskTitle(exactly), (title: exactly, rest: ''));
  });

  test('a longer one is cut at the last space that fits', () {
    final words = 'word ' * 300;

    final cut = cutTaskTitle(words.trim());

    expect(cut.title, ('word ' * 200).trim());
    expect(cut.title.runes.length, lessThanOrEqualTo(max));
    expect(cut.rest, ('word ' * 100).trim());
  });

  test('a space right after the limit is a cut that loses nothing', () {
    final text = '${'a' * max} tail';

    expect(cutTaskTitle(text), (title: 'a' * max, rest: 'tail'));
  });

  test('without a space it is cut at the limit, counted in code points', () {
    final emoji = '😀' * (max + 5);

    final cut = cutTaskTitle(emoji);

    expect(cut.title, '😀' * max);
    expect(cut.title.length, 2 * max);
    expect(cut.rest, '😀' * 5);
  });

  test('a character as shown is never split', () {
    const accented = 'é';
    final text = '${'a' * (max - 1)}$accented${'b' * 10}';

    final cut = cutTaskTitle(text);

    expect(cut.title, 'a' * (max - 1));
    expect(cut.rest, '$accented${'b' * 10}');
  });

  test('one character longer than the limit is cut by code points', () {
    final text = 'a${'́' * (max + 1)}';

    final cut = cutTaskTitle(text);

    expect(cut.title.runes.length, max);
    expect('${cut.title}${cut.rest}', text);
  });

  group('a web address the cut would split', () {
    final address = 'https://example.org/read?page=${'a' * max}';

    test('goes to the rest whole, its host the title', () {
      expect(cutTaskTitle(address), (title: 'example.org', rest: address));
      expect(
        cutTaskTitle(address.replaceFirst('https', 'HTTP')).title,
        'example.org',
      );
    });

    test('after text leaves the text as the title', () {
      final words = ('word ' * 150).trim();

      expect(cutTaskTitle('Read this $address'), (
        title: 'Read this',
        rest: address,
      ));
      expect(cutTaskTitle('$words $address'), (title: words, rest: address));
    });

    test('without a host that fits is cut at the limit', () {
      final hostOnly = 'https://${'a' * (max + 1)}';

      final cut = cutTaskTitle(hostOnly);

      expect(cut.title, hostOnly.substring(0, max));
      expect(cut.rest, 'a' * 9);
    });
  });

  test('a long word that is no web address is cut at the limit', () {
    final text = 'www.example.org/${'a' * max}';

    final cut = cutTaskTitle(text);

    expect(cut.title, text.substring(0, max));
    expect(cut.rest, 'a' * 16);
  });

  test('nothing is lost: the title and the rest make the text again', () {
    final text = 'Lorem ipsum dolor sit amet, ' * 60;

    final cut = cutTaskTitle(text.trim());

    expect('${cut.title} ${cut.rest}', text.trim());
  });
}
