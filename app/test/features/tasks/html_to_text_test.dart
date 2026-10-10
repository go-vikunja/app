import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/features/tasks/application/html_to_text.dart';

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
}
