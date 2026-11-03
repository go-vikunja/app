import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/utils/priority.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

void main() {
  group('Priority utility tests', () {
    late AppLocalizations loc;

    setUpAll(() async {
      // Load English localizations for deterministic test values
      loc = await AppLocalizations.delegate.load(const Locale('en'));
    });

    group('priorityToString', () {
      final testCases = <int?, String>{
        0: 'Unset',
        1: 'Low',
        2: 'Medium',
        3: 'High',
        4: 'Urgent',
        5: 'DO NOW',
        -1: '',
        6: '',
        10: '',
        100: '',
        null: '',
      };

      testCases.forEach((input, expected) {
        test('Priority $input should return "$expected"', () {
          expect(priorityToString(loc, input), expected);
        });
      });
    });
  });
}
