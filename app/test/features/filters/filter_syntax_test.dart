import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/features/filters/application/filter_syntax.dart';

void main() {
  TextEditingValue at(String text, [int? caret]) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: caret ?? text.length),
  );

  List<(String, FilterSpanKind)> parts(String text) => [
    for (final span in filterSpans(text))
      (text.substring(span.start, span.end), span.kind),
  ];

  group('filterSpans', () {
    test('fields, operators, values and joins, left to right', () {
      expect(parts('done = false && priority >= 3'), [
        ('done', FilterSpanKind.field),
        ('=', FilterSpanKind.operator),
        ('false', FilterSpanKind.value),
        ('&&', FilterSpanKind.join),
        ('priority', FilterSpanKind.field),
        ('>=', FilterSpanKind.operator),
        ('3', FilterSpanKind.value),
      ]);
    });

    test('word operators need a space on each side, as on the server', () {
      expect(parts('labels in Work, Home || project not in 3'), [
        ('labels', FilterSpanKind.field),
        ('in', FilterSpanKind.operator),
        ('Work, Home', FilterSpanKind.value),
        ('||', FilterSpanKind.join),
        ('project', FilterSpanKind.field),
        ('not in', FilterSpanKind.operator),
        ('3', FilterSpanKind.value),
      ]);
      expect(parts('title like report'), [
        ('title', FilterSpanKind.field),
        ('like', FilterSpanKind.operator),
        ('report', FilterSpanKind.value),
      ]);
    });

    test('brackets are joins and end a value', () {
      expect(parts('(due_date < now/d+1d)'), [
        ('(', FilterSpanKind.join),
        ('due_date', FilterSpanKind.field),
        ('<', FilterSpanKind.operator),
        ('now/d+1d', FilterSpanKind.value),
        (')', FilterSpanKind.join),
      ]);
    });

    test('a value runs to the next & | ( ), taking later words with it, '
        'which shows why the server refuses it', () {
      expect(parts('done = false and priority = 1'), [
        ('done', FilterSpanKind.field),
        ('=', FilterSpanKind.operator),
        ('false and priority = 1', FilterSpanKind.value),
      ]);
      expect(parts("title = 'a && b'"), [
        ('title', FilterSpanKind.field),
        ('=', FilterSpanKind.operator),
        ("'a", FilterSpanKind.value),
        ('&&', FilterSpanKind.join),
      ]);
    });

    test('a word no field is named so; the web spellings count, in any '
        'case', () {
      expect(parts('dueDat < now'), [
        ('dueDat', FilterSpanKind.unknownField),
        ('<', FilterSpanKind.operator),
        ('now', FilterSpanKind.value),
      ]);
      expect(parts('dueDate < now').first, ('dueDate', FilterSpanKind.field));
      expect(parts('bucket_id = 3').first, ('bucket_id', FilterSpanKind.field));
      expect(parts('DONE = true').first, ('DONE', FilterSpanKind.field));
      expect(parts('Hex_Color = ff0000').first, (
        'Hex_Color',
        FilterSpanKind.unknownField,
      ));
    });

    test('a field without a value yet, and plain text, have no value', () {
      expect(parts('done = '), [
        ('done', FilterSpanKind.field),
        ('=', FilterSpanKind.operator),
      ]);
      expect(parts('just words'), isEmpty);
    });
  });

  group('filterCompletionContext', () {
    test('at the start and after a join: a field', () {
      expect(
        filterCompletionContext(at('')),
        isA<FieldContext>().having((c) => c.partial, 'partial', ''),
      );
      final context = filterCompletionContext(at('done = false && pri'));
      expect(
        context,
        isA<FieldContext>()
            .having((c) => c.partial, 'partial', 'pri')
            .having((c) => c.start, 'start', 16)
            .having((c) => c.end, 'end', 19),
      );
      expect(
        filterCompletionContext(at('(du')),
        isA<FieldContext>().having((c) => c.partial, 'partial', 'du'),
      );
    });

    test('a field followed by a space: its operators', () {
      final context = filterCompletionContext(at('labels '));
      expect(
        context,
        isA<OperatorContext>()
            .having((c) => c.field, 'field', 'labels')
            .having((c) => c.kind, 'kind', FilterFieldKind.labels)
            .having((c) => c.partial, 'partial', ''),
      );
      expect(operatorSuggestions(context! as OperatorContext), [
        '=',
        '!=',
        'in',
        'not in',
      ]);
      final typing = filterCompletionContext(at('labels no'))!;
      expect(operatorSuggestions(typing as OperatorContext), ['not in']);
      final symbol = filterCompletionContext(at('priority !'))!;
      expect(operatorSuggestions(symbol as OperatorContext), ['!=']);
    });

    test('after an operator: the value typed so far', () {
      expect(
        filterCompletionContext(at('done = fa')),
        isA<ValueContext>()
            .having((c) => c.field, 'field', 'done')
            .having((c) => c.kind, 'kind', FilterFieldKind.done)
            .having((c) => c.operator, 'operator', '=')
            .having((c) => c.partial, 'partial', 'fa')
            .having((c) => c.start, 'start', 7)
            .having((c) => c.joinable, 'joinable', isFalse),
      );
      expect(
        filterCompletionContext(at('due_date <')),
        isA<ValueContext>().having((c) => c.partial, 'partial', ''),
      );
    });

    test('in a list, the item after the last comma', () {
      final context = filterCompletionContext(at('labels in Work, Ho'));
      expect(
        context,
        isA<ValueContext>()
            .having((c) => c.operator, 'operator', 'in')
            .having((c) => c.partial, 'partial', 'Ho')
            .having((c) => c.start, 'start', 16),
      );
    });

    test('an opening quote is not part of what is looked for', () {
      expect(
        filterCompletionContext(at('labels = "Work T')),
        isA<ValueContext>()
            .having((c) => c.partial, 'partial', 'Work T')
            .having((c) => c.start, 'start', 9),
      );
    });

    test('a value and a space can be joined', () {
      expect(
        filterCompletionContext(at('done = false ')),
        isA<ValueContext>().having((c) => c.joinable, 'joinable', isTrue),
      );
      expect(filterCompletionContext(at('(done = true) ')), isA<JoinContext>());
    });

    test('nothing for an unknown field, half a join or a selection', () {
      expect(filterCompletionContext(at('foo = ')), isNull);
      expect(filterCompletionContext(at('done = true & ')), isNull);
      expect(
        filterCompletionContext(
          const TextEditingValue(
            text: 'done',
            selection: TextSelection(baseOffset: 0, extentOffset: 4),
          ),
        ),
        isNull,
      );
    });
  });

  group('fieldSuggestions', () {
    test('every field for nothing typed, the common ones first', () {
      final fields = fieldSuggestions(
        const FieldContext(start: 0, end: 0, partial: ''),
      );
      expect(fields.take(3), ['done', 'priority', 'dueDate']);
      expect(fields, isNot(contains('uid')));
      expect(fields, isNot(contains('bucket_id')));
    });

    test('ignoring case and underscores, those that start with it first', () {
      expect(
        fieldSuggestions(const FieldContext(start: 0, end: 4, partial: 'dueD')),
        ['dueDate'],
      );
      expect(
        fieldSuggestions(const FieldContext(start: 0, end: 2, partial: 'cr')),
        ['created', 'createdBy', 'description'],
      );
    });
  });

  group('completeFilter', () {
    TextEditingValue complete(String text, String insert, [int? caret]) {
      final value = at(text, caret);
      return completeFilter(value, filterCompletionContext(value)!, insert);
    }

    test('a field, then its operator, then a value, each followed by a '
        'space', () {
      expect(complete('pri', 'priority'), at('priority '));
      expect(complete('priority ', '>='), at('priority >= '));
      expect(complete('priority >= ', '3'), at('priority >= 3 '));
    });

    test('the whole word under the caret is replaced', () {
      expect(complete('dued < now', 'dueDate', 2), at('dueDate < now', 8));
    });

    test('an operator gets its space before, a join both', () {
      expect(complete('done!', '!='), at('done != '));
      expect(complete('(done = true)', '&&'), at('(done = true) && '));
    });

    test('a list item replaces only what is typed after the comma', () {
      expect(
        complete('labels in Work, Ho', 'Home'),
        at('labels in Work, Home '),
      );
    });

    test('a value typed in quotes is replaced with its quotes', () {
      expect(
        complete('labels = "Wo', filterValueText('Work', list: false)),
        at('labels = Work '),
      );
    });
  });

  test('filterValueText quotes what a value would otherwise lose', () {
    expect(filterValueText('Work To Do', list: false), 'Work To Do');
    expect(filterValueText('A, B', list: false), '"A, B"');
    expect(filterValueText(' padded', list: true), '" padded"');
    expect(filterValueText('say "hi", now', list: false), "'say \"hi\", now'");
  });

  test('canBeFilterValue refuses what ends a value early', () {
    expect(canBeFilterValue('Work', list: false), isTrue);
    expect(canBeFilterValue('R&D', list: false), isFalse);
    expect(canBeFilterValue('Phase (2)', list: false), isFalse);
    expect(canBeFilterValue('A, B', list: false), isTrue);
    expect(canBeFilterValue('A, B', list: true), isFalse);
  });
}
