import 'package:datetime_picker_formfield/datetime_picker_formfield.dart';
import 'package:flutter/material.dart';

import 'package:vikunja_app/theme/constants.dart';

class VikunjaDateTimePicker extends StatelessWidget {
  final String label;
  final void Function(DateTime?)? onSaved;
  final void Function(DateTime?)? onChanged;
  final DateTime? initialValue;
  final EdgeInsetsGeometry padding;
  final Icon icon;
  final InputBorder border;

  const VikunjaDateTimePicker({
    Key? key,
    required this.label,
    this.onSaved,
    this.onChanged,
    this.initialValue,
    this.padding = const EdgeInsets.symmetric(vertical: 10.0),
    this.icon = const Icon(Icons.date_range),
    this.border = InputBorder.none,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DateTimeField(
      //dateOnly: false,
      //editable: false, // Otherwise editing the date is not possible, this setting affects the underlying text field.
      initialValue: initialValue == null || initialValue!.year <= 1
          ? null
          : initialValue!.toLocal(),
      format: vDateFormatLong,
      decoration: InputDecoration(
        labelText: label,
        border: border,
        icon: icon,
      ),
      onSaved: onSaved,
      onChanged: onChanged,
      onShowPicker: (context, currentValue) {
        if(currentValue == null)
          currentValue = DateTime.now();
        return _showDatePickerFuture(context, currentValue);
      },
    );
  }

  Future<DateTime?> _showDatePickerFuture(context, currentValue) {
    return showDialog(
        context: context,
        builder: (_) => DatePickerDialog(
          initialDate: currentValue.year <= 1
              ? DateTime.now()
              : currentValue,
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
          initialCalendarMode: DatePickerMode.day,
        )).then((date) {
          if(date == null)
            return null;
          return showDialog(
          context: context,
          builder: (_) =>
              TimePickerDialog(
                initialTime: TimeOfDay.fromDateTime(currentValue),
              )
      ).then((time) {
        if(time == null)
          return null;
        return DateTime(date.year,date.month, date.day,time.hour,time.minute);
          });
    });
  }
}
