import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/text/html_to_text.dart';

void main() {
  test('paragraphs and breaks become line breaks', () {
    expect(
      htmlToPlainText('<p>First</p><p>Second<br>line</p>'),
      'First\nSecond\nline',
    );
  });

  test('lists get bullets, checklists get boxes', () {
    final html = [
      '<ul><li><p>one</p></li><li><p>two</p></li></ul>',
      '<ul data-type="taskList">',
      '<li data-checked="true" data-type="taskItem" data-task-id="ab12">',
      '<label><input type="checkbox" checked="checked"><span></span></label>',
      '<div><p>done</p></div></li>',
      '<li data-checked="false" data-type="taskItem"><div><p>open</p></div>',
      '</li></ul>',
    ].join();

    expect(htmlToPlainText(html), '• one\n• two\n\n☑ done\n☐ open');
  });

  test('tags are dropped, entities decoded', () {
    expect(
      htmlToPlainText(
        '<p>Tom &amp; Jerry &lt;3 &quot;quotes&quot; &#39;x&#39;'
        ' &#x41;&#66; caf&eacute;&nbsp;!</p>',
      ),
      'Tom & Jerry <3 "quotes" \'x\' AB caf&eacute;\u00a0!',
    );
  });

  test('a reference to half a surrogate pair is one replacement mark in its '
      'spot', () {
    expect(
      htmlToPlainText('<p>a&#xD800;b &#56320;c &#xdfff;</p>'),
      'a\uFFFDb \uFFFDc \uFFFD',
    );
  });

  test('two halves of a pair are a mark each, as the rich text reads them', () {
    const html = '<p>&#xD83D;&#xDE00; &#x1F600;</p>';

    expect(htmlToPlainText(html), '\uFFFD\uFFFD \u{1F600}');
    expect(
      htmlToPlainText(html),
      parseRichText(
        html,
        apiRoot: Uri.parse('https://tasks.example.com'),
        taskLinkBases: const [],
      ).plainText,
    );
  });

  test('headings, blockquotes and tables keep their lines', () {
    expect(
      htmlToPlainText(
        '<h1>Title</h1><blockquote><p>quoted</p></blockquote>'
        '<table><tr><td>a</td><td>b</td></tr><tr><td>c</td></tr></table>',
      ),
      'Title\nquoted\n\nab\nc',
    );
  });

  test('links keep their text, images vanish, scripts are only text', () {
    final html = [
      '<p>See <a href="https://x" target="_blank">the docs</a>',
      '<img src="/api/v2/tasks/1/attachments/2"></p>',
      '<script>alert(1)</script>',
    ].join();

    expect(htmlToPlainText(html), 'See the docs\nalert(1)');
  });

  test('an empty or whitespace description is empty', () {
    expect(htmlToPlainText(''), '');
    expect(htmlToPlainText('<p></p>'), '');
    expect(htmlToPlainText('  \n '), '');
  });

  test('plain text passes through', () {
    expect(htmlToPlainText('just text'), 'just text');
  });

  test('a mention shows its label, else the username', () {
    expect(
      htmlToPlainText(
        '<p>Kannst du das übernehmen, <mention-user data-id="anna" '
        'data-label="Anna B"></mention-user>?</p>',
      ),
      'Kannst du das übernehmen, @Anna B?',
    );
    expect(
      htmlToPlainText('<p>Hi <mention-user data-id="anna"></mention-user></p>'),
      'Hi @anna',
    );
  });

  // A collaborator's description or comment is hostile input; a search that
  // starts again from every position takes minutes on most of these runs.
  group('a long run finishes quickly', () {
    String run(String unit) => unit * (300000 ~/ unit.length);

    // The test's own timeout cannot stop synchronous work, so the time is
    // checked after it.
    void timedTest(String description, void Function() body) {
      test(description, () {
        final watch = Stopwatch()..start();
        body();
        expect(watch.elapsed, lessThan(const Duration(seconds: 20)));
      });
    }

    timedTest("of '<' without a '>'", () {
      expect(htmlToPlainText(run('<')), run('<'));
    });

    timedTest("of '<li ', with and without a '>'", () {
      expect(htmlToPlainText(run('<li ')), run('<li ').trim());
      expect(htmlToPlainText('${run('<li ')}>'), '•');
    });

    timedTest("of '</p>', with and without a '</li>' after it", () {
      expect(htmlToPlainText('a${run('</p>')}b'), 'a\n\nb');
      expect(htmlToPlainText('<li>a${run('</p>')}</li>'), '• a');
    });

    timedTest("of '<p>'", () {
      expect(htmlToPlainText('${run('<p>')}a'), 'a');
    });

    timedTest('of spaces, with and without a line break after them', () {
      expect(htmlToPlainText('a${run(' ')}b'), 'a${run(' ')}b');
      expect(htmlToPlainText('a${run(' ')}\nb'), 'a\nb');
    });

    timedTest("of '<mention-user ', with and without a '>'", () {
      expect(
        htmlToPlainText(run('<mention-user ')),
        run('<mention-user ').trim(),
      );
      expect(htmlToPlainText('${run('<mention-user ')}>'), '');
    });
  });
}
