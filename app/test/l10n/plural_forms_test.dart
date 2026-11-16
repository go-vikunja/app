import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every plural branch in [message] as (the plural's argument, the
/// selector, the branch's text).
Iterable<(String, String, String)> _pluralBranches(String message) sync* {
  final plurals = RegExp(r'\{\s*(\w+)\s*,\s*plural\s*,');
  final branchStart = RegExp(r'\s*(=\s*\d+|\w+)\s*\{');
  for (final plural in plurals.allMatches(message)) {
    var index = plural.end;
    while (true) {
      final branch = branchStart.matchAsPrefix(message, index);
      if (branch == null) break;
      var end = branch.end;
      for (var depth = 1; depth > 0; end++) {
        if (message[end] == '{') depth++;
        if (message[end] == '}') depth--;
      }
      final selector = branch[1]!.replaceAll(RegExp(r'\s'), '');
      yield (plural[1]!, selector, message.substring(branch.end, end - 1));
      index = end;
    }
  }
}

void main() {
  test('an English plural shows its number in the one form and has no =1 '
      'form: some languages use the one form for 21 or 31 too, and '
      'translators copy the English', () {
    final english = jsonDecode(
      File('lib/l10n/arb/app_en.arb').readAsStringSync(),
    ) as Map<String, Object?>;

    final offenders = {
      for (final MapEntry(:key, :value) in english.entries)
        if (!key.startsWith('@'))
          for (final (argument, selector, text) in _pluralBranches(
            value! as String,
          ))
            if (selector == '=1' ||
                (selector == 'one' && !text.contains('{$argument}')))
              key,
    };

    expect(offenders, isEmpty);
  });

  test('the check finds an =1 form and a one form without its number', () {
    expect(
      _pluralBranches('{count, plural, =1{One task} other{{count} tasks}}')
          .toList(),
      [('count', '=1', 'One task'), ('count', 'other', '{count} tasks')],
    );
    expect(
      _pluralBranches('Wait {n,plural, one {a {kind} second} other{{n} s}}.')
          .toList(),
      [('n', 'one', 'a {kind} second'), ('n', 'other', '{n} s')],
    );
  });
}
