import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

const _scheme = 'vikunja-dev.coderoftime.vikunja';

void main() {
  group('parseTaskReference', () {
    final cases = <String, TaskReference?>{
      '12': const TaskById(12),
      ' 12 ': const TaskById(12),
      '0012': const TaskById(12),
      '9007199254740991': const TaskById(9007199254740991),
      'PROJ-12': const TaskByIdentifier('PROJ', 12),
      'proj-12': const TaskByIdentifier('proj', 12),
      'PROJ-0012': const TaskByIdentifier('PROJ', 12),
      'MY-PRJ-12': const TaskByIdentifier('MY-PRJ', 12),
      'X Y933-1': const TaskByIdentifier('X Y933', 1),
      'STRAßE-3': const TaskByIdentifier('STRAßE', 3),
      'ÄB9332-1': const TaskByIdentifier('ÄB9332', 1),
      '129332-4': const TaskByIdentifier('129332', 4),
      '#9332-1': const TaskByIdentifier('#9332', 1),
      'PA.933-2': const TaskByIdentifier('PA.933', 2),
      '  PROJ-7\n': const TaskByIdentifier('PROJ', 7),
      '': null,
      '   ': null,
      '0': null,
      '00': null,
      '9007199254740992': null,
      '99999999999999999999': null,
      'PROJ-': null,
      '-12': null,
      'PROJ-0': null,
      'PROJ-1x': null,
      'PROJ-+1': null,
      'PROJ--1': const TaskByIdentifier('PROJ-', 1),
      'PROJ-9007199254740992': null,
      '#12': null,
      'PROJ': null,
      '12abc': null,
      '-': null,
      '١٢': null,
    };
    for (final MapEntry(key: text, value: expected) in cases.entries) {
      test('"$text"', () => expect(parseTaskReference(text), expected));
    }
  });

  group('parseTaskDeepLink', () {
    final cases = <String, TaskDeepLink?>{
      '$_scheme://task/12': const TaskDeepLink(TaskById(12)),
      '$_scheme://task/PA9332-1': const TaskDeepLink(
        TaskByIdentifier('PA9332', 1),
      ),
      '$_scheme://task/X%20Y933-1': const TaskDeepLink(
        TaskByIdentifier('X Y933', 1),
      ),
      '$_scheme://task/%C3%84B-2': const TaskDeepLink(
        TaskByIdentifier('ÄB', 2),
      ),
      '$_scheme://task/12?account=a1': const TaskDeepLink(
        TaskById(12),
        account: 'a1',
      ),
      '$_scheme://task/12?account=': const TaskDeepLink(TaskById(12)),
      '$_scheme://task/12?other=x#frag': const TaskDeepLink(TaskById(12)),
      'VIKUNJA-DEV.CODEROFTIME.VIKUNJA://TASK/12': const TaskDeepLink(
        TaskById(12),
      ),
      '$_scheme://oauth/callback?code=x': null,
      '$_scheme://task/': null,
      '$_scheme://task': null,
      '$_scheme://task/12/': null,
      '$_scheme://task/12/34': null,
      '$_scheme://task//12': null,
      '$_scheme://task/0': null,
      '$_scheme://task/abc': null,
      '$_scheme://user@task/12': null,
      '$_scheme://task:80/12': null,
      '$_scheme:task/12': null,
      'https://task/12': null,
      'other-app://task/12': null,
      '$_scheme://task/%FF': null,
      '$_scheme://task/12?account=%FF': null,
    };
    for (final MapEntry(key: link, value: expected) in cases.entries) {
      test(link, () {
        expect(parseTaskDeepLink(Uri.parse(link), scheme: _scheme), expected);
      });
    }
  });

  group('buildTaskDeepLink round trips', () {
    final links = [
      const TaskDeepLink(TaskById(1)),
      const TaskDeepLink(TaskById(9007199254740991), account: 'acc-1'),
      const TaskDeepLink(TaskByIdentifier('PROJ', 12)),
      const TaskDeepLink(TaskByIdentifier('MY-PRJ', 3), account: 'a b/c?'),
      const TaskDeepLink(TaskByIdentifier('X Y933', 1)),
      const TaskDeepLink(TaskByIdentifier('STRAßE', 7)),
      const TaskDeepLink(TaskByIdentifier('A/B#?', 2)),
      const TaskDeepLink(TaskByIdentifier('129332', 4)),
    ];
    for (final link in links) {
      test('$link', () {
        final uri = buildTaskDeepLink(
          link.reference,
          scheme: _scheme,
          account: link.account,
        );

        expect(uri.scheme, _scheme);
        expect(uri.host, 'task');
        expect(parseTaskDeepLink(uri, scheme: _scheme), link);
        expect(
          parseTaskDeepLink(Uri.parse(uri.toString()), scheme: _scheme),
          link,
        );
      });
    }

    test('the exact form', () {
      expect(
        buildTaskDeepLink(const TaskById(12), scheme: _scheme).toString(),
        '$_scheme://task/12',
      );
      expect(
        buildTaskDeepLink(
          const TaskByIdentifier('PA9332', 1),
          scheme: _scheme,
          account: 'x',
        ).toString(),
        '$_scheme://task/PA9332-1?account=x',
      );
      expect(
        buildTaskDeepLink(
          const TaskById(3),
          scheme: _scheme,
          account: '',
        ).toString(),
        '$_scheme://task/3',
      );
    });
  });
}
