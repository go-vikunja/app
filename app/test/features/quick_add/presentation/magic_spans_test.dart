import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_lines.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_plan.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_spans.dart';

void main() {
  // A Saturday at noon.
  final now = DateTime(2026, 10, 10, 12);

  /// A plan as the service makes it, as far as the spans need it: the
  /// parser's result, magic only when nothing is left of the title.
  QuickAddPlan planOf(
    String line, {
    QuickAddMagicMode mode = QuickAddMagicMode.vikunja,
    bool projectFound = true,
  }) {
    final parsed = parseTaskText(line, now: now, mode: mode);
    return QuickAddPlan(
      input: line,
      parsed: parsed,
      title: parsed.text,
      project: null,
      unmatchedProject: projectFound ? null : parsed.project,
      magicOnly: parsed.text.isEmpty && line.trim().isNotEmpty,
    );
  }

  List<(String, MagicSpanKind)> spansOf(
    String line, {
    QuickAddMagicMode mode = QuickAddMagicMode.vikunja,
    bool projectFound = true,
  }) => [
    for (final span in magicSpansForLine(
      line,
      planOf(line, mode: mode, projectFound: projectFound),
      quickAddPrefixes(mode)!,
    ))
      (line.substring(span.start, span.end), span.kind),
  ];

  test('finds every part of a mixed line, in order', () {
    expect(
      spansOf(
        'Reifen wechseln *wichtig *neu +Garage @sam !3 tomorrow at 9:00 '
        'every week',
      ),
      [
        ('*wichtig', MagicSpanKind.label),
        ('*neu', MagicSpanKind.label),
        ('+Garage', MagicSpanKind.project),
        ('@sam', MagicSpanKind.assignee),
        ('!3', MagicSpanKind.priority),
        ('tomorrow at 9:00', MagicSpanKind.date),
        ('every week', MagicSpanKind.repeat),
      ],
    );
  });

  test('the parts can stand anywhere and between words', () {
    expect(spansOf('tomorrow call *phone Sam at 15:00'), [
      ('tomorrow', MagicSpanKind.date),
      ('*phone', MagicSpanKind.label),
      ('at 15:00', MagicSpanKind.date),
    ]);
  });

  test('a quoted label covers its quotes and spaces', () {
    expect(spansOf('Plan *"Road trip" next week'), [
      ('*"Road trip"', MagicSpanKind.label),
      ('next week', MagicSpanKind.date),
    ]);
  });

  test('a project that matched nothing is marked as such', () {
    expect(spansOf('Call +Nowhere', projectFound: false), [
      ('+Nowhere', MagicSpanKind.unmatchedProject),
    ]);
  });

  /// The spans of [line] by where they start, for a part that also stands
  /// elsewhere in the line.
  List<(int, String, MagicSpanKind)> startsOf(String line) => [
    for (final span in magicSpansForLine(
      line,
      planOf(line),
      quickAddPrefixes(QuickAddMagicMode.vikunja)!,
    ))
      (span.start, line.substring(span.start, span.end), span.kind),
  ];

  test('D102-8: a priority is a whole number, so !3abc is none', () {
    expect(spansOf('Fix !3abc'), isEmpty);
    expect(spansOf('Fix !3 abc'), [('!3', MagicSpanKind.priority)]);
  });

  test('D102-8: the priority is the token the parser removes, whole', () {
    expect(spansOf('Lorem !03 x'), [('!03', MagicSpanKind.priority)]);
    expect(startsOf('Fix !3abc !3'), [(10, '!3', MagicSpanKind.priority)]);
    expect(startsOf('Fix !03 !3'), [(4, '!03', MagicSpanKind.priority)]);
    expect(spansOf('x !!3'), [('!!3', MagicSpanKind.priority)]);
    expect(spansOf("x !'3'"), [("!'3'", MagicSpanKind.priority)]);
    expect(spansOf('x *"a !2 b" !3'), [
      ('*"a !2 b"', MagicSpanKind.label),
      ('!3', MagicSpanKind.priority),
    ]);
  });

  test('D102-1, D102-2: a date phrase where the parser removes it, not '
      "out of `today's` or a longer time", () {
    expect(startsOf("Fix today's build today"), [
      (18, 'today', MagicSpanKind.date),
    ]);
    expect(spansOf("Plan may's party 5th may"), [
      ('5th may', MagicSpanKind.date),
    ]);
    expect(startsOf('x at 22:5 y at 22'), [(12, 'at 22', MagicSpanKind.date)]);
    expect(startsOf('x at 9 y at 9 pm'), [(2, 'at 9', MagicSpanKind.date)]);
  });

  test('a repeat without a date', () {
    expect(spansOf('Water plants every 3 days'), [
      ('every 3 days', MagicSpanKind.repeat),
    ]);
  });

  test('a repeat inside the date words, in any case', () {
    expect(spansOf('Gym tomorrow Every Day at 18:00'), [
      ('tomorrow', MagicSpanKind.date),
      ('Every Day', MagicSpanKind.repeat),
      ('at 18:00', MagicSpanKind.date),
    ]);
  });

  test('an ordinal date with its month and time', () {
    expect(spansOf('Meet Ana sep 17th at 10:00'), [
      ('sep 17th at 10:00', MagicSpanKind.date),
    ]);
  });

  test("the parser's phrases, not a word that only looks the same", () {
    expect(spansOf('Dinner at 7 next friday at the station'), [
      ('at 7 next friday', MagicSpanKind.date),
    ]);
    expect(spansOf('tomorrow at 9 at home'), [
      ('tomorrow at 9', MagicSpanKind.date),
    ]);
  });

  test('a date word inside a quoted project is no date', () {
    const line = '+"stuff tomorrow" tomorrow';
    final parsed = parseTaskText(line, now: now);
    final plan = QuickAddPlan(
      input: line,
      parsed: ParsedTaskText(
        text: '+"stuff tomorrow"',
        date: parsed.date,
        project: parsed.project,
        datePhrases: parsed.datePhrases,
      ),
      title: '+"stuff tomorrow"',
      project: null,
      unmatchedProject: parsed.project,
    );
    expect(
      [
        for (final span in magicSpansForLine(
          line,
          plan,
          quickAddPrefixes(QuickAddMagicMode.vikunja)!,
        ))
          (line.substring(span.start, span.end), span.kind),
      ],
      [
        ('+"stuff tomorrow"', MagicSpanKind.unmatchedProject),
        ('tomorrow', MagicSpanKind.date),
      ],
    );
    expect(
      magicSpansForLine(
        line,
        plan,
        quickAddPrefixes(QuickAddMagicMode.vikunja)!,
      ).last.start,
      18,
    );
  });

  test('nothing for text the parser leaves alone', () {
    expect(spansOf('Read todays paper'), isEmpty);
    expect(spansOf('fix monitor stand'), isEmpty);
    expect(spansOf('email@example.com'), isEmpty);
  });

  test('a person stays in the title but is marked; @today is no date', () {
    expect(spansOf('Ping @today'), [('@today', MagicSpanKind.assignee)]);
  });

  test('nothing for a magic-only line or a quoted title', () {
    expect(spansOf('*urgent tomorrow'), isEmpty);
    expect(spansOf('"Buy *milk tomorrow"'), isEmpty);
  });

  test('todoist prefixes', () {
    expect(
      spansOf(
        'Buy milk @groceries #Home +sam !2 tomorrow',
        mode: QuickAddMagicMode.todoist,
      ),
      [
        ('@groceries', MagicSpanKind.label),
        ('#Home', MagicSpanKind.project),
        ('+sam', MagicSpanKind.assignee),
        ('!2', MagicSpanKind.priority),
        ('tomorrow', MagicSpanKind.date),
      ],
    );
  });

  test('the spans of several lines are offset into the whole text', () {
    const text = 'Buy *milk\n\n  - Call Sam tomorrow';
    final spans = magicSpansOf(
      text,
      quickAddPrefixes(QuickAddMagicMode.vikunja)!,
      planOf,
    );
    expect(
      [for (final span in spans) text.substring(span.start, span.end)],
      ['*milk', 'tomorrow'],
    );
    expect(magicLines(text), [
      (offset: 0, text: 'Buy *milk'),
      (offset: 15, text: 'Call Sam tomorrow'),
    ]);
  });

  test('lines are split and cut as the save splits them: at every line '
      'break, a single line as typed, of several each without its indent '
      'and list marker, and no line for a marker alone', () {
    const crlf = 'Buy *milk\r\n+ Call Sam\rWash +Home';
    final lines = magicLines(crlf);
    expect(lines, [
      (offset: 0, text: 'Buy *milk'),
      (offset: 13, text: 'Call Sam'),
      (offset: 22, text: 'Wash +Home'),
    ]);
    expect([for (final line in lines) line.text], splitQuickAddLines(crlf));
    for (final line in lines) {
      expect(
        crlf.substring(line.offset, line.offset + line.text.length),
        line.text,
      );
    }

    expect(magicLines('  - [ ] Alone'), [(offset: 0, text: '  - [ ] Alone')]);
    const withMarkerOnly = 'Trip\n- \n  - Pack';
    expect([
      for (final line in magicLines(withMarkerOnly)) line.text,
    ], splitQuickAddLines(withMarkerOnly));
  });

  group('the tokens are the ones the parser reads', () {
    test('an unclosed quote ends at the next label, which is marked too', () {
      expect(spansOf('Buy *"milk *urgent'), [
        ('*"milk', MagicSpanKind.label),
        ('*urgent', MagicSpanKind.label),
      ]);
    });

    test('a quoted label holding ` *` is two labels, each marked', () {
      expect(planOf('x *"a *b" c').parsed.labels, ['a', 'b"']);
      expect(spansOf('x *"a *b" c'), [
        ('*"a', MagicSpanKind.label),
        ('*b"', MagicSpanKind.label),
      ]);
    });

    test('a doubled prefix at the start is marked with the label the '
        'parser keeps there', () {
      expect(planOf('**bike now').parsed.labels, ['*bike']);
      expect(
        magicSpansForLine(
          '**bike now',
          planOf('**bike now'),
          quickAddPrefixes(QuickAddMagicMode.vikunja)!,
        ),
        [const MagicSpan(0, 6, MagicSpanKind.label, item: '*bike')],
      );
    });
  });

  test('prefixed tokens follow the web grammar', () {
    expect(
      [
        for (final token in quickAddTokens('*a b*c *"d e" @@x *', '*'))
          token.item,
      ],
      ['a', 'd e', ''],
    );
    expect(
      [for (final token in quickAddTokens('x @@alice', '@')) token.item],
      ['alice'],
    );
  });
}
