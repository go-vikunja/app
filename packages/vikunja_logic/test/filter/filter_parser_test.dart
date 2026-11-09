import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/src/filter/filter_nodes.dart';
import 'package:vikunja_logic/src/filter/filter_preprocess.dart';
import 'package:vikunja_logic/src/filter/go_values.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import 'filter_test_support.dart';

FilterError _error(String filter) => parseTaskFilter(filter) as FilterError;

void main() {
  group('empty filters', () {
    test('only the empty string is no filter', () {
      final result = parseTaskFilter('');

      expect(result, FilterExpression.matchAll);
      expect((result as FilterExpression).isEmpty, isTrue);
    });

    test('blanks are a syntax error, as on the server', () {
      for (final filter in [' ', '\t', '\n  ']) {
        expect(_error(filter).code, FilterError.invalidExpression);
      }
    });

    test('a filter of dropped conditions matches everything', () {
      final expression = parsed('assignees like x || (created_by like y)');

      expect(expression.isEmpty, isTrue);
      expect(expression.fields, {'assignees', 'created_by'});
    });
  });

  group('errors name what is wrong without quoting the filter', () {
    test('4016 names the field', () {
      final error = _error('dueDate < now');

      expect(error.code, FilterError.invalidField);
      expect(error.field, 'dueDate');
      expect(error.value, isNull);
    });

    test('4019 names the field as the server spells it, and the value', () {
      final error = _error('project = Inbox');

      expect(error.code, FilterError.invalidValue);
      expect(error.field, 'project_id');
      expect(error.value, 'Inbox');
      expect(error.message, isNot(contains('Inbox')));
    });

    test('4017 for fexpr signs the server has no comparator for', () {
      for (final sign in ['!~', '?~', '?!~', '?<', '?<=', '?>', '?>=']) {
        final error = _error('title $sign x');

        expect(error.code, FilterError.invalidComparator, reason: sign);
        expect(error.field, 'title');
      }
    });

    test('4024 never echoes the filter', () {
      final error = _error("title = 'secret && plan'");

      expect(error.code, FilterError.invalidExpression);
      expect(error.message, isNot(contains('secret')));
    });

    test('the first group with an error decides', () {
      expect(_error('foo = 1 && done = yes').code, FilterError.invalidField);
      expect(_error('done = yes && foo = 1').code, FilterError.invalidValue);
      expect(_error('(done = true || bar = 1) && done = yes').field, 'bar');
    });

    test('like on anything but text is 4019', () {
      for (final filter in [
        'done like true',
        'priority like 3',
        'percent_done like 0.5',
        'due_date like now',
        'reminders like now',
        'labels like 4',
        'bucket_id like 1',
      ]) {
        expect(_error(filter).code, FilterError.invalidValue, reason: filter);
      }
    });

    test('what the server answers with a 500 is refused as a value', () {
      for (final filter in [
        'position > 0',
        'position = 1',
        'assignees > a',
        'assignees <= a',
        'created_by >= a',
      ]) {
        expect(_error(filter).code, FilterError.invalidValue, reason: filter);
      }
    });

    test('uid is always 4019', () {
      expect(_error('uid = abc').code, FilterError.invalidValue);
      expect(_error('uid like abc').code, FilterError.invalidValue);
    });
  });

  group('values', () {
    test("integers follow Go's ParseInt", () {
      expect(parseTaskFilter('priority = +3'), isA<FilterExpression>());
      expect(parseTaskFilter('priority = -003'), isA<FilterExpression>());
      for (final value in [
        '0x10',
        '1_000',
        '3.0',
        '1e3',
        '9223372036854775808',
      ]) {
        expect(_error('priority = $value').code, FilterError.invalidValue);
      }
    });

    test("decimals follow Go's ParseFloat", () {
      for (final value in ['0.5', '.5', '5.', '1e-1', '-0', 'Inf', 'nan']) {
        expect(
          parseTaskFilter('percent_done = $value'),
          isA<FilterExpression>(),
          reason: value,
        );
      }
      for (final value in ['1e400', '0.5.1', 'half', '']) {
        expect(
          _error("percent_done = '$value'").code,
          FilterError.invalidValue,
        );
      }
    });

    test("booleans follow Go's ParseBool", () {
      for (final value in ['1', 't', 'T', 'TRUE', 'true', 'True']) {
        expect(parseTaskFilter('done = $value'), isA<FilterExpression>());
      }
      for (final value in ['yes', 'tRuE', 'on', '2']) {
        expect(_error('done = $value').code, FilterError.invalidValue);
      }
    });

    test('lists refuse an empty item except for usernames', () {
      expect(_error('labels in 1,,2').code, FilterError.invalidValue);
      expect(_error('priority in 1,').code, FilterError.invalidValue);
      expect(parseTaskFilter('title in a,,b'), isA<FilterExpression>());
      final usernames = parsed('assignees in , a ,, b,');
      final condition =
          (usernames.root.items.single.node as FilterConditionNode).condition;
      expect(condition.values, ['a', 'b']);
    });

    test('quoted values lose their quotes and escapes', () {
      final cases = {
        "title = 'a b'": 'a b',
        'title = "a b"': 'a b',
        r"title = 'it\'s'": "it's",
        r'title = "say \"hi\""': 'say "hi"',
        r"title = 'a\tb'": 'a\tb',
        r"title = 'a\qb'": r'a\qb',
        "title = ' padded '": 'padded',
        "title = it's": "it's",
      };
      for (final MapEntry(key: filter, value: expected) in cases.entries) {
        final condition =
            (parsed(filter).root.items.single.node as FilterConditionNode)
                .condition;
        expect(condition.values.single, expected, reason: filter);
      }
    });
  });

  group('the rewrites before parsing', () {
    test('values are quoted, running to the next & | ( or )', () {
      expect(quoteValues('done = false'), "done = 'false'");
      expect(
        quoteValues('done=false&&priority>3'),
        "done = 'false'&&priority > '3'",
      );
      expect(
        quoteValues('done = false and priority = 1'),
        "done = 'false and priority = 1'",
      );
      expect(quoteValues("title = foo's"), r"title = 'foo\'s'");
      expect(quoteValues("title = 'a'"), "title = 'a'");
      expect(quoteValues("title = '"), "title = '");
      expect(quoteValues('priority ?= (1,2)'), "priority ?= ''(1,2)");
      // Go's \s is ASCII, its TrimSpace Unicode but without U+FEFF.
      expect(quoteValues('done =\u00a0true\u00a0'), "done = 'true'");
      expect(quoteValues('done = \ufefftrue'), "done = '\ufefftrue'");
    });

    test('the quoting matches the server regex on random input', () {
      // The server's pattern, with Go's ASCII classes spelled out.
      final reference = RegExp(
        r'(\w+)[\t\n\f\r ]*(>=|<=|!=|~|\?=|\?!=|=|>|<)[\t\n\f\r ]*([^&|()]+)',
      );
      String quotedByRegex(String filter) =>
          filter.replaceAllMapped(reference, (match) {
            final value = goTrimSpace(match[3]!);
            final quoted =
                (value.startsWith("'") && value.endsWith("'")) ||
                    (value.startsWith('"') && value.endsWith('"'))
                ? value
                : "'${value.replaceAll("'", r"\'")}'";
            return '${match[1]} ${match[2]} $quoted';
          });
      const alphabet = [
        'a',
        'b',
        '1',
        '_',
        ' ',
        ' ',
        '\t',
        '=',
        '>',
        '<',
        '!',
        '~',
        '?',
        '&',
        '|',
        '(',
        ')',
        "'",
        '"',
        'ä',
        ',',
      ];
      final random = Random(16);
      var changed = 0;
      for (var round = 0; round < 20000; round++) {
        final filter = [
          for (var i = random.nextInt(14); i > 0; i--)
            alphabet[random.nextInt(alphabet.length)],
        ].join();
        final quoted = quotedByRegex(filter);
        expect(quoteValues(filter), quoted, reason: filter);
        if (quoted != filter) changed++;
      }
      expect(changed, greaterThan(1000));
    });

    test('a long word costs linear time, not quadratic', () {
      final stopwatch = Stopwatch()..start();
      parseTaskFilter('a' * 16000);
      parseTaskFilter('${'(' * 100}${'a' * 15000}${')' * 100}');

      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });

    test('limits count UTF-8 bytes', () {
      final ascii = 'title = ${'a' * (16384 - 8)}';
      final umlauts = 'title = ${'ä' * ((16384 - 8) ~/ 2 + 1)}';

      expect(complexityError(ascii), isNull);
      expect(complexityError(umlauts)?.code, FilterError.tooComplex);
    });

    test('parentheses in closed quotes do not count, in open ones they do', () {
      expect(complexityError("title = '))' && done = true"), isNull);
      expect(
        complexityError("title = '))"),
        isA<FilterError>().having(
          (e) => e.code,
          'code',
          FilterError.invalidExpression,
        ),
      );
    });
  });

  group('the parser', () {
    test('a group drops a half-built condition before it', () {
      expect(
        parsed('done (priority = 1)').toString(),
        'FilterExpression((priority = 1))',
      );
    });

    test('comments are skipped', () {
      expect(
        parsed('(// note\ndone = true)').toString(),
        'FilterExpression((done = true))',
      );
    });

    test('a NUL ends the input, as the server reads it', () {
      expect(_error('done = true\u0000x').code, FilterError.invalidExpression);
    });

    test("a function call's name is the field", () {
      expect(_error('due_date(1) = 3').code, FilterError.invalidValue);
      expect(_error('foo(1, "a") = 3').code, FilterError.invalidField);
      expect(_error('foo(1,) = 3').code, FilterError.invalidExpression);
      expect(_error('a(b(c(d(1)))) = 3').code, FilterError.invalidExpression);
    });

    test("names follow fexpr's identifier rules", () {
      expect(_error('_ = 1').code, FilterError.invalidExpression);
      expect(_error('a. = 1').code, FilterError.invalidExpression);
      expect(_error('@x = 1').code, FilterError.invalidField);
      expect(_error('a.b:c = 1').code, FilterError.invalidField);
    });

    test('a quoted field name works', () {
      expect(parsed("'done' = true").fields, {'done'});
    });

    test('only && and || join', () {
      for (final filter in [
        'done = true & priority = 1',
        'done = true ||| priority = 1',
        'done = true || || priority = 1',
        '&& done = true',
        'done = true &&',
        '(done = true) done = true',
      ]) {
        expect(_error(filter).code, FilterError.invalidExpression);
      }
    });
  });

  group('the shape the server builds', () {
    test('project is project_id', () {
      expect(parsed('project = 1').fields, {'project_id'});
    });

    test('consecutive &&-joined ranges on one relation merge', () {
      FilterNode first(String filter) => parsed(filter).root.items.first.node;

      expect(
        first('labels > 4 && labels < 10'),
        isA<FilterRangeNode>().having(
          (n) => n.conditions,
          'conditions',
          hasLength(2),
        ),
      );
      expect(
        first('reminders > now && reminders < now+7d && reminders != now'),
        isA<FilterRangeNode>().having(
          (n) => n.conditions,
          'conditions',
          hasLength(2),
        ),
      );
      expect(parsed('labels > 4 || labels < 10').root.items, hasLength(2));
      expect(parsed('labels > 4 && labels = 10').root.items, hasLength(2));
      expect(parsed('labels > 4 && reminders < now').root.items, hasLength(2));
      expect(
        parsed('due_date > now && due_date < now+1d').root.items,
        hasLength(2),
      );
    });

    test('the merged group keeps the join of its first condition', () {
      final items = parsed(
        'done = true || reminders > now && reminders < now+1d',
      ).root.items;

      expect(items, hasLength(2));
      expect(items.last.or, isTrue);
    });

    test('a dropped condition takes its join along', () {
      expect(
        parsed('assignees like x || done = true').toString(),
        'FilterExpression(done = true)',
      );
      expect(
        parsed('done = true && (created_by like a) || priority = 1').toString(),
        'FilterExpression(done = true || priority = 1)',
      );
    });

    test('equal filters are equal', () {
      expect(
        parsed('done = false && labels in 1, 2'),
        parsed('done=false&&labels in 1,2'),
      );
      expect(parsed('done = false'), isNot(parsed('done = true')));
      expect(parsed('due_date < now'), parsed("due_date < 'now'"));
    });
  });

  group('matchesOnlyOpenTasks', () {
    final cases = {
      'done = false': true,
      'done = 0': true,
      'done != true': true,
      'done < true': true,
      'done in false': true,
      'done not in true': true,
      'done = true': false,
      'done = false && priority > 2': true,
      'priority > 2 && done = false': true,
      'priority > 2 || done = false': false,
      'done = false || priority > 2': false,
      'priority = 1 || priority = 2 && done = false': true,
      '(done = false || priority = 1) && done = false': true,
      'done = false && priority = 1 || done = false && priority = 2': true,
      'done = false && priority = 1 || priority = 2': false,
      '(done = false && labels = 1) || (done = false && labels = 2)': true,
      'done = false || done = 0': true,
      '': false,
    };
    for (final MapEntry(key: filter, value: expected) in cases.entries) {
      test("'$filter' is $expected", () {
        expect(parsed(filter).matchesOnlyOpenTasks, expected);
      });
    }
  });

  group('usesRelativeDates', () {
    final cases = {
      'due_date < now': true,
      'due_date >= now/d && due_date < now/d+1d': true,
      'done = false && (priority > 2 || start_date > now-7d)': true,
      'reminders > now && reminders < 2030-01-01': true,
      'done = false || due_date in 2026-10-20, now+1w': true,
      'due_date < 2026-10-20': false,
      'due_date < 2026': false,
      'due_date > 1760000000000': false,
      'due_date < 2026-10-20 22:00': false,
      "title like 'now'": false,
      'done = false': false,
      '': false,
    };
    for (final MapEntry(key: filter, value: expected) in cases.entries) {
      test("'$filter' is $expected", () {
        expect(parsed(filter).usesRelativeDates, expected);
      });
    }
  });

  group('like on a field that is not text', () {
    test('is refused only after the rest of the filter converts', () {
      expect(parseTaskFilter('labels like 4'), _errorWithCode(4019));
      expect(
        parseTaskFilter('labels like 4 && foo = 1'),
        _errorWithCode(4016, field: 'foo'),
      );
      expect(
        parseTaskFilter('priority like 3 && dueDate < now'),
        _errorWithCode(4016, field: 'dueDate'),
      );
      expect(
        parseTaskFilter('priority like 3 && due_date < tomorrow'),
        _errorWithCode(4019, field: 'due_date'),
      );
      expect(
        parseTaskFilter('done = true && (priority like 3 || labels like 4)'),
        _errorWithCode(4019, field: 'priority'),
      );
    });
  });

  // As Vikunja 2.8.0 answered; 2.7.1 accepted all of these.
  group('business days, at most 10000 over the whole filter', () {
    test('count by amount whatever the sign, a bare b as one', () {
      for (final filter in [
        'due_date < now+10000b',
        'due_date < now-10000b',
        'due_date < now+010000b',
        'due_date < now+5000b+5000b',
        'due_date < now+5000b+5000d',
        'due_date < now+9999b && due_date < now+b',
        'due_date < now+10000b && due_date < now+0b',
        'due_date in now+6000b, now+4000b',
        'due_date < 2023-02-05-10000b',
        'title = now+10001b && due_date < now+b',
        'assignees in now+10001b',
      ]) {
        expect(
          parseTaskFilter(filter),
          isA<FilterExpression>(),
          reason: filter,
        );
      }
    });

    test('more is 4019 for the value that goes over', () {
      final cases = {
        'due_date < now+10001b': ('due_date', 'now+10001b'),
        'due_date < now-10001b': ('due_date', 'now-10001b'),
        'reminders < now+10001b': ('reminders', 'now+10001b'),
        'due_date < now+5000b-5001b': ('due_date', 'now+5000b-5001b'),
        'due_date < now+10000b && due_date < now-b': ('due_date', 'now-b'),
        'due_date in now+6000b, now+4001b': (
          'due_date',
          'now+6000b, now+4001b',
        ),
        '(due_date < now+6000b || done = true) && start_date > now-4001b': (
          'start_date',
          'now-4001b',
        ),
        'done_at < now+6000b && created > now+3000b && updated > now+1001b': (
          'updated',
          'now+1001b',
        ),
        'due_date < now+0000000000000000000010001b': (
          'due_date',
          'now+0000000000000000000010001b',
        ),
        'due_date < now+99999999999999999999b': (
          'due_date',
          'now+99999999999999999999b',
        ),
        // Not date math, yet counted: the lenient Y-M-D ignores the rest.
        'due_date < 2023-02-05-10001b': ('due_date', '2023-02-05-10001b'),
      };
      for (final MapEntry(key: filter, value: (field, value))
          in cases.entries) {
        final error = _error(filter);

        expect(error.code, FilterError.invalidValue, reason: filter);
        expect(error.field, field, reason: filter);
        expect(error.value, value, reason: filter);
      }
    });

    test('the conditions convert in order', () {
      expect(
        parseTaskFilter('due_date < now+10001b && foo = 1'),
        _errorWithCode(4019, field: 'due_date'),
      );
      expect(
        parseTaskFilter('foo = 1 && due_date < now+10001b'),
        _errorWithCode(4016, field: 'foo'),
      );
      expect(
        parseTaskFilter('priority like 3 && due_date < now+10001b'),
        _errorWithCode(4019, field: 'due_date'),
      );
      expect(
        _error('due_date like now+6000b && due_date < now+4001b').value,
        'now+4001b',
      );
    });

    test("a request ANDed with a view's filter shares the limit", () {
      expect(
        parseTaskFilter('(due_date > now-4000b) && (due_date < now+6000b)'),
        isA<FilterExpression>(),
      );
      expect(
        _error('(due_date > now-4001b) && (due_date < now+6000b)').value,
        'now+6000b',
      );
    });
  });
}

Matcher _errorWithCode(int code, {String? field}) => isA<FilterError>()
    .having((error) => error.code, 'code', code)
    .having((error) => error.field, 'field', field ?? anything);
