import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColorPickerDialog extends StatefulWidget {
  final Color? _pickerColor;
  final Function() onCancel;
  final Function(Color) onConfirm;

  ColorPickerDialog(this._pickerColor, this.onConfirm, this.onCancel);

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  Color? _pickerColor;

  @override
  void initState() {
    _pickerColor = widget._pickerColor;

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Task Color'),
      content: SingleChildScrollView(
        child: ColorPicker(
          pickerColor: _pickerColor ?? Colors.black,
          enableAlpha: false,
          labelTypes: const [ColorLabelType.hsl, ColorLabelType.rgb],
          paletteType: PaletteType.hslWithLightness,
          hexInputBar: true,
          onColorChanged: (color) => setState(() {
            _pickerColor = color;
          }),
        ),
      ),
      actions: <TextButton>[
        TextButton(
          child: Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text('Reset'),
          onPressed: () {
            setState(() {
              _pickerColor = Colors.black;
            });
          },
        ),
        TextButton(
          child: Text('Ok'),
          onPressed: () {
            widget.onConfirm(_pickerColor ?? Colors.black);
          },
        ),
      ],
    );
  }
}
