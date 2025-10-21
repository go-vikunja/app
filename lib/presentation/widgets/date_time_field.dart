import 'package:datetime_picker_formfield_new/datetime_picker_formfield.dart';
import 'package:flutter/material.dart';
import 'package:vikunja_app/core/utils/constants.dart';

class VikunjaDateTimeField extends StatelessWidget {
  final String label;
  final void Function(DateTime?)? onSaved;
  final void Function(DateTime?)? onChanged;
  final DateTime? initialValue;
  final Icon icon;

  const VikunjaDateTimeField({
    super.key,
    required this.label,
    this.onSaved,
    this.onChanged,
    this.initialValue,
    this.icon = const Icon(Icons.date_range),
  });

  @override
  Widget build(BuildContext context) {
    return DateTimeField(
      initialValue: initialValue == null || initialValue!.year <= 1
          ? null
          : initialValue!.toLocal(),
      format: vDateFormatShort,
      decoration: InputDecoration(
        labelText: label,
        border: InputBorder.none,
        icon: icon,
      ),
      onSaved: onSaved,
      onChanged: onChanged,
      onShowPicker: (context, currentValue) {
        return _showDatePicker(context, currentValue ?? DateTime.now());
      },
    );
  }

  Future<DateTime?> _showDatePicker(context, currentValue) async {
    var selectedDate = await showDialog<DateTime>(
      context: context,
      builder: (_) => DatePickerDialog(
        initialDate: currentValue.year <= 1 ? DateTime.now() : currentValue,
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
        initialCalendarMode: DatePickerMode.day,
      ),
    );

    if (selectedDate == null) return null;

    var selectedTime = await showDialog<TimeOfDay>(
      context: context,
      builder: (_) =>
          TimePickerDialog(initialTime: TimeOfDay.fromDateTime(currentValue)),
    );

    if (selectedTime == null) return null;

    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
  }
}
