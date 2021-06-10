import 'package:datetime_picker_formfield/datetime_picker_formfield.dart';
import 'package:flutter/material.dart';

import 'package:vikunja_app/theme/constants.dart';

class VikunjaDateTimePicker extends StatelessWidget {
  final String label;
  final Function onSaved;
  final Function onChanged;
  final DateTime initialValue;
  final EdgeInsetsGeometry padding;
  final Icon icon;
  final InputBorder border;

  const VikunjaDateTimePicker({
    Key key,
    @required this.label,
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
      initialValue: initialValue == DateTime.fromMillisecondsSinceEpoch(0)
          ? null
          : initialValue,
      format: vDateFormatLong,
      decoration: InputDecoration(
        labelText: label,
        border: border,
        icon: icon,
      ),
      onSaved: onSaved,
      onChanged: onChanged,
      onShowPicker: (context, currentValue) {
        return showDatePicker(
            context: context,
            firstDate: DateTime(1900),
            initialDate: currentValue.millisecondsSinceEpoch > 0 ? currentValue : DateTime.now(),
            lastDate: DateTime(2100));
      },
    );
  }
}
