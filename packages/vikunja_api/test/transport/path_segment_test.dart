import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/src/transport/path_segment.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  test('a name becomes one encoded segment', () {
    expect(pathSegment('anna.b'), 'anna.b');
    expect(pathSegment('a/b c'), 'a%2Fb%20c');
    expect(pathSegment('...'), '...');
  });

  test('a name of only one or two dots is refused, as it would address the '
      'parent path', () {
    expect(() => pathSegment('.'), throwsA(isA<ValidationFailed>()));
    expect(() => pathSegment('..'), throwsA(isA<ValidationFailed>()));
  });
}
