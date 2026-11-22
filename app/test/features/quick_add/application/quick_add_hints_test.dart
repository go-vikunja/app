import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_hints.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_plan.dart';

void main() {
  QuickAddDateHint? hintFor(String line) {
    final parsed = parseTaskText(line, now: DateTime(2026, 10, 10, 12));
    return quickAddDateHint(
      QuickAddPlan(
        input: line,
        parsed: parsed,
        title: parsed.text,
        project: null,
      ),
    );
  }

  test('a German date word without a date points at the English ones', () {
    for (final line in [
      'Zahnarzt morgen um 17 Uhr',
      'Müll übermorgen',
      'Übermorgen Müll',
      'Bericht bis Freitag',
      'Training montags',
      'Bericht bis 17 Uhr',
      'Bericht bis 17:30Uhr',
      'Treffen um 9:30',
      'Geburtstag 17. Dezember',
      'nächste Woche planen',
      'Antwort in 3 Tagen',
      'Am Wochenende putzen',
    ]) {
      expect(hintFor(line), isA<ForeignDateWords>(), reason: line);
    }
  });

  test('no hint once a date is found, for English words, or for a title '
      'quoted whole', () {
    for (final line in [
      'Zahnarzt morgen 17.12.',
      'Zahnarzt am 17.12. at 17',
      'Buy milk',
      'Do laundry',
      'So what',
      'Ask Morgan',
      'Mondays are hard',
      'um, 5 apples',
      '"Zahnarzt morgen"',
      'Call tomorrow at 5pm',
    ]) {
      expect(hintFor(line), isNull, reason: line);
    }
  });

  test('a clock time right after the date asks for at', () {
    final cases = {
      'Call tomorrow 5pm': '5pm',
      'Call tomorrow 5 PM sharp': '5 PM',
      'Call friday 17:30': '17:30',
      'Call next monday 9:15am': '9:15am',
      '17.12. 9:00 Arzt': '9:00',
    };
    for (final MapEntry(key: line, value: time) in cases.entries) {
      expect(
        hintFor(line),
        isA<TimeWithoutAt>().having((hint) => hint.time, 'time', time),
        reason: line,
      );
    }
  });

  test('no time hint with a time already, or for what is no clock time', () {
    for (final line in [
      'Call tomorrow at 5pm',
      'Call tomorrow 5pm at 6pm',
      'Buy tomorrow 3 apples',
      'Call tomorrow 17:75',
      'Call tomorrow 13pm',
      'Call 5pm tomorrow',
    ]) {
      expect(hintFor(line), isNull, reason: line);
    }
  });
}
