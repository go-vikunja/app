import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

// The web's window origin plus base path is the first base (the server the
// account uses), `frontend_url` the second.
List<Uri> _basesOf(Map<String, Object?> context) {
  final frontendUrl = context['frontendUrl']! as String;
  return [
    Uri.parse('${context['windowOrigin']}${context['basePath']}'),
    if (frontendUrl.isNotEmpty) ?Uri.tryParse(frontendUrl),
  ];
}

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/parseTaskIdFromUrl_vectors.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final contexts = fixture['contexts']! as Map<String, Object?>;
  final vectors = (fixture['vectors']! as List<Object?>)
      .cast<Map<String, Object?>>();

  test('29 upstream and 38 edge vectors', () {
    expect(vectors.where((v) => v['upstream'] == true), hasLength(29));
    expect(vectors, hasLength(67));
  });

  for (final vector in vectors) {
    final context = vector['context']! as String;
    final href = vector['href']! as String;
    final label = vector['test'] ?? vector['note'];
    test('$context ${jsonEncode(href)}: $label', () {
      final bases = _basesOf(contexts[context]! as Map<String, Object?>);
      // A string marks an id beyond JavaScript's safe integers.
      final expected = switch (vector['expected']) {
        final int id => id,
        _ => null,
      };

      expect(parseTaskIdFromUrl(href, bases: bases), expected);
    });
  }

  test('no usable base, no task', () {
    expect(parseTaskIdFromUrl('/tasks/5', bases: const []), isNull);
    expect(
      parseTaskIdFromUrl('/tasks/5', bases: [Uri.parse('ftp://example.com/')]),
      isNull,
    );
  });

  test('the server root may come without a trailing slash', () {
    final bases = [Uri.parse('https://example.com/vikunja')];

    expect(parseTaskIdFromUrl('/vikunja/tasks/3', bases: bases), 3);
    expect(
      parseTaskIdFromUrl('https://example.com/vikunja/tasks/4', bases: bases),
      4,
    );
    expect(parseTaskIdFromUrl('/tasks/3', bases: bases), isNull);
  });

  test('a path-relative href resolves against the origin, like the web', () {
    final bases = [Uri.parse('https://example.com/vikunja/')];

    expect(parseTaskIdFromUrl('tasks/3', bases: bases), isNull);
    expect(parseTaskIdFromUrl('vikunja/tasks/3', bases: bases), 3);
  });
}
