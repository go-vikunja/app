import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

AttachmentRef _ref(int taskId, int attachmentId) =>
    AttachmentRef(taskId: taskId, attachmentId: attachmentId);

void main() {
  group('a server at the root', () {
    final apiRoot = Uri.parse('https://vikunja.example.com');
    final cases = <String, AttachmentRef?>{
      'https://vikunja.example.com/api/v2/tasks/5/attachments/9': _ref(5, 9),
      'https://vikunja.example.com/api/v1/tasks/5/attachments/9': _ref(5, 9),
      'https://vikunja.example.com/tasks/5/attachments/9': _ref(5, 9),
      'HTTPS://VIKUNJA.example.com/api/v2/tasks/5/attachments/9': _ref(5, 9),
      'https://vikunja.example.com:443/api/v2/tasks/5/attachments/9': _ref(
        5,
        9,
      ),
      ' https://vikunja.example.com/api/v2/tasks/5/attachments/9 ': _ref(5, 9),
      '/api/v2/tasks/5/attachments/9': _ref(5, 9),
      '/tasks/5/attachments/9': _ref(5, 9),
      'https://vikunja.example.com/api/v2/tasks/0012/attachments/009': _ref(
        12,
        9,
      ),
      'https://attacker.example/tasks/5/attachments/9': null,
      'https://vikunja.example.com.evil/api/v2/tasks/5/attachments/9': null,
      'http://vikunja.example.com/api/v2/tasks/5/attachments/9': null,
      'https://vikunja.example.com:8443/api/v2/tasks/5/attachments/9': null,
      'https://user@vikunja.example.com/api/v2/tasks/5/attachments/9': null,
      'https://vikunja.example.com/api/v3/tasks/5/attachments/9': null,
      'https://vikunja.example.com/sub/api/v2/tasks/5/attachments/9': null,
      'https://vikunja.example.com/api/v2/tasks/5/attachments/9/': null,
      'https://vikunja.example.com/api/v2/tasks/5/attachments/9?x=1': null,
      'https://vikunja.example.com/api/v2/tasks/5/attachments/9#a': null,
      'https://vikunja.example.com/api/v2/tasks/x/attachments/9': null,
      'https://vikunja.example.com/api/v2/tasks/5/attachments/-9': null,
      'https://vikunja.example.com/api/v2/tasks/5/attachments/9.0': null,
      'https://vikunja.example.com/api/v2/tasks/5/attachments/'
              '99999999999999999999':
          null,
      'https://vikunja.example.com/?x=/tasks/5/attachments/9': null,
      '//vikunja.example.com/api/v2/tasks/5/attachments/9': null,
      'tasks/5/attachments/9': null,
      '#': null,
      '': null,
    };
    for (final MapEntry(key: src, value: expected) in cases.entries) {
      test('"$src"', () {
        expect(parseAttachmentUrl(src, apiRoot: apiRoot), expected);
      });
    }
  });

  group('a server under a sub-path', () {
    for (final root in [
      'https://example.com/vikunja',
      'https://example.com/vikunja/',
      'https://example.com/vikunja/api/v1',
      'https://example.com/vikunja/api/v2/',
    ]) {
      test(root, () {
        final apiRoot = Uri.parse(root);

        expect(
          parseAttachmentUrl(
            'https://example.com/vikunja/api/v2/tasks/1/attachments/2',
            apiRoot: apiRoot,
          ),
          _ref(1, 2),
        );
        expect(
          parseAttachmentUrl(
            '/vikunja/api/v1/tasks/1/attachments/2',
            apiRoot: apiRoot,
          ),
          _ref(1, 2),
        );
        expect(
          parseAttachmentUrl('/tasks/1/attachments/2', apiRoot: apiRoot),
          _ref(1, 2),
        );
        expect(
          parseAttachmentUrl(
            'https://example.com/api/v2/tasks/1/attachments/2',
            apiRoot: apiRoot,
          ),
          isNull,
        );
        expect(
          parseAttachmentUrl(
            '/other/api/v2/tasks/1/attachments/2',
            apiRoot: apiRoot,
          ),
          isNull,
        );
      });
    }
  });

  test('equality', () {
    expect(_ref(1, 2), _ref(1, 2));
    expect(_ref(1, 2).hashCode, _ref(1, 2).hashCode);
    expect(_ref(1, 2), isNot(_ref(2, 1)));
  });
}
