import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/src/negotiation/punycode.dart';

void main() {
  // Vectors from Python's punycode codec.
  for (final (label, encoded) in [
    ('bücher', 'bcher-kva'),
    ('münchen', 'mnchen-3ya'),
    ('mañana', 'maana-pta'),
    ('straße', 'strae-oqa'),
    ('ü', 'tda'),
    ('abcü', 'abc-joa'),
    ('例え', 'r8jz45g'),
    ('日本語', 'wgv71a119e'),
    ('αβγ', 'mxacd'),
    ('пример', 'e1afmkfd'),
    ('ドメイン名例', 'eckwd4c7cu47r2wf'),
  ]) {
    test('$label -> $encoded', () {
      expect(punycodeEncode(label), encoded);
    });
  }
}
