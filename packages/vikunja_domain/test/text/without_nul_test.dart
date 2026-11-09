import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  test('every U+0000 goes, everything else stays', () {
    expect(withoutNul('\u0000Mi\u0000lk\u0000\u0000'), 'Milk');
    expect(withoutNul('😀 \u0001 é'), '😀 \u0001 é');
    expect(withoutNul(r'a\u0000b'), r'a\u0000b');
    expect(withoutNul(''), '');
  });
}
