import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/features/share/application/share_text.dart';

void main() {
  group('sharedTaskText', () {
    test('the subject is the title and the whole text the description', () {
      final text = sharedTaskText(
        subject: ' Release notes ',
        text: 'Read this\nhttps://example.org/notes',
      );

      expect(text.title, 'Release notes');
      expect(text.notes, 'Read this\nhttps://example.org/notes');
      expect(
        text.description,
        '<p>Read this<br><a target="_blank" rel="noopener noreferrer nofollow" '
        'href="https://example.org/notes">https://example.org/notes</a></p>',
      );
    });

    test('without a subject the first line is the title', () {
      final text = sharedTaskText(text: '\n  Buy milk  \r\nand bread\n\nsoon');

      expect(text.title, 'Buy milk');
      expect(text.notes, 'and bread\n\nsoon');
      expect(text.description, '<p>and bread</p><p>soon</p>');
    });

    test('a single line leaves no description', () {
      final text = sharedTaskText(text: 'https://example.org');

      expect(text.title, 'https://example.org');
      expect(text.description, '');
    });

    test('a subject over several lines becomes one line', () {
      expect(sharedTaskText(subject: 'a\nb').title, 'a b');
    });

    test('without text the name of the one file is the title', () {
      final text = sharedTaskText(singleFileName: 'scan.pdf');

      expect(text.title, 'scan.pdf');
      expect(text.description, '');
      expect(sharedTaskText().title, '');
    });
  });

  group('sharedTextHtml', () {
    test('markup and entities are escaped, never interpreted', () {
      expect(
        sharedTextHtml('<img src=x onerror=alert(1)> & "quotes" \'too\''),
        '<p>&lt;img src=x onerror=alert(1)&gt; &amp; "quotes" \'too\'</p>',
      );
    });

    test('only http(s) addresses become links', () {
      expect(
        sharedTextHtml('javascript:alert(1) ftp://x.org mailto:a@b.c'),
        '<p>javascript:alert(1) ftp://x.org mailto:a@b.c</p>',
      );
    });

    test('punctuation after an address stays outside the link', () {
      const attributes = 'target="_blank" rel="noopener noreferrer nofollow"';
      expect(
        sharedTextHtml('See https://example.org/a. (also https://x.org/b)!'),
        '<p>See <a $attributes '
        'href="https://example.org/a">https://example.org/a</a>. (also '
        '<a $attributes href="https://x.org/b">https://x.org/b</a>)!</p>',
      );
      expect(
        sharedTextHtml('https://en.wikipedia.org/wiki/Llama_(disambiguation)'),
        contains('href="https://en.wikipedia.org/wiki/Llama_(disambiguation)"'),
      );
    });

    test('an address with a query keeps it, escaped in the attribute', () {
      expect(
        sharedTextHtml('https://example.org/?a=1&b="2"'),
        '<p><a target="_blank" rel="noopener noreferrer nofollow" '
        'href="https://example.org/?a=1&amp;b=">https://example.org/?a=1&amp;b='
        '</a>"2"</p>',
      );
    });

    test('blank lines separate paragraphs, empty text is no paragraph', () {
      expect(sharedTextHtml('a\n \nb\n\n\n'), '<p>a</p><p>b</p>');
      expect(sharedTextHtml('  \n '), '');
    });
  });

  group('sharedTextToAppend', () {
    test('the subject goes first unless the text starts with it', () {
      expect(
        sharedTextToAppend(subject: 'Page', text: 'https://x.org'),
        'Page\nhttps://x.org',
      );
      expect(
        sharedTextToAppend(subject: 'Note', text: 'Note: buy'),
        'Note: buy',
      );
      expect(sharedTextToAppend(subject: 'Only'), 'Only');
      expect(sharedTextToAppend(text: ' text '), 'text');
      expect(sharedTextToAppend(), '');
    });
  });

  group('appendToDescription', () {
    test('goes after the description, replaces an empty one', () {
      expect(appendToDescription('<p>a</p>', '<p>b</p>'), '<p>a</p><p>b</p>');
      expect(appendToDescription('', '<p>b</p>'), '<p>b</p>');
      expect(appendToDescription('<p></p>', '<p>b</p>'), '<p>b</p>');
    });
  });
}
