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

    group('priorityFromString', () {
      final testCases = <String?, int>{
        'Low': 1,
        'Medium': 2,
        'High': 3,
        'Urgent': 4,
        'DO NOW': 5,
        'Invalid': 0,
        'low': 0, // case sensitive
        'HIGH': 0, // case sensitive
        '': 0,
        'Unknown Priority': 0,
        'Unset': 0,
        null: 0,
      };

      testCases.forEach((input, expected) {
        String description = input == null ? 'null' : '"$input"';
        test('$description should return $expected', () {
          expect(priorityFromString(loc, input), expected);
        });
      });
    });

    group('Round-trip conversion tests', () {
      test('Priority to string and back should be consistent', () {
        for (int i = 0; i <= 5; i++) {
          String priorityString = priorityToString(loc, i);
          if (priorityString.isNotEmpty) {
            int roundTripPriority = priorityFromString(loc, priorityString);
            expect(
              roundTripPriority,
              i,
              reason:
                  'Priority $i should convert to "$priorityString" and back to $i',
            );
          }
        }
      });

      test(
        'String to priority and back should be consistent for valid strings',
        () {
          List<String> validPriorityStrings = [
            'Low',
            'Medium',
            'High',
            'Urgent',
            'DO NOW',
          ];

          for (String priorityString in validPriorityStrings) {
            int priority = priorityFromString(loc, priorityString);
            String roundTripString = priorityToString(loc, priority);
            expect(
              roundTripString,
              priorityString,
              reason:
                  'Priority string "$priorityString" should convert to $priority and back to "$priorityString"',
            );
          }
        },
      );
    });
  });
}
