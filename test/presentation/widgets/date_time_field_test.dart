import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/utils/date_extensions.dart';
import 'package:vikunja_app/presentation/widgets/date_time_field.dart';

import '../../helpers/test_app.dart';

/// `DateTimeField` renders a plain `TextField`, not a `TextFormField`.
String fieldText(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller.text;

void main() {
  setUpAll(loadL10n);

  Future<DateTime?> pumpField(
    WidgetTester tester, {
    DateTime? initialValue,
    Icon icon = const Icon(Icons.date_range),
  }) async {
    DateTime? changed;
    await pumpApp(
      tester,
      VikunjaDateTimeField(
        label: 'Due date',
        initialValue: initialValue,
        icon: icon,
        onChanged: (value) => changed = value,
      ),
      inScaffold: true,
    );
    await tester.pumpAndSettle();
    return changed;
  }

  group('rendering', () {
    testWidgets('shows its label and icon', (tester) async {
      await pumpField(tester);

      expect(find.text('Due date'), findsOneWidget);
      expect(find.byIcon(Icons.date_range), findsOneWidget);
    });

    testWidgets('accepts a custom icon', (tester) async {
      await pumpField(tester, icon: const Icon(Icons.access_time));

      expect(find.byIcon(Icons.access_time), findsOneWidget);
    });

    testWidgets('shows a formatted initial date', (tester) async {
      final initial = DateTime(2030, 5, 6, 7, 8);

      await pumpField(tester, initialValue: initial);

      expect(find.text(initial.formatShort()), findsOneWidget);
    });

    testWidgets('starts empty without an initial date', (tester) async {
      await pumpField(tester);

      expect(fieldText(tester), isEmpty);
    });

    testWidgets('treats the year-1 sentinel as empty', (tester) async {
      await pumpField(tester, initialValue: DateTime.utc(1));

      expect(fieldText(tester), isEmpty);
    });
  });

  group('picking a date and time', () {
    testWidgets('tapping the field opens the date picker', (tester) async {
      await pumpField(tester);

      await tapAndSettle(tester, find.byType(TextField));

      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('cancelling the date picker changes nothing', (tester) async {
      await pumpField(tester);

      await tapAndSettle(tester, find.byType(TextField));
      await tapAndSettle(tester, find.text('Cancel'));

      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.byType(TimePickerDialog), findsNothing);
    });

    testWidgets('confirming a date opens the time picker', (tester) async {
      await pumpField(tester, initialValue: DateTime(2030, 5, 6, 7, 8));

      await tapAndSettle(tester, find.byType(TextField));
      await tapAndSettle(tester, find.text('OK'));

      expect(find.byType(TimePickerDialog), findsOneWidget);
    });

    testWidgets('cancelling the time picker leaves the field unchanged', (
      tester,
    ) async {
      final initial = DateTime(2030, 5, 6, 7, 8);
      await pumpField(tester, initialValue: initial);

      await tapAndSettle(tester, find.byType(TextField));
      await tapAndSettle(tester, find.text('OK'));
      await tapAndSettle(tester, find.text('Cancel'));

      expect(find.text(initial.formatShort()), findsOneWidget);
    });

    testWidgets('confirming both pickers writes the date into the field', (
      tester,
    ) async {
      final initial = DateTime(2030, 5, 6, 7, 8);
      await pumpField(tester, initialValue: initial);

      await tapAndSettle(tester, find.byType(TextField));
      await tapAndSettle(tester, find.text('OK'));
      await tapAndSettle(tester, find.text('OK'));

      expect(find.byType(TimePickerDialog), findsNothing);
      expect(find.text(initial.formatShort()), findsOneWidget);
    });
  });
}
