import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.taskColorTitle),
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
          child: Text(l10n.cancel),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text(l10n.reset),
          onPressed: () {
            setState(() {
              _pickerColor = Colors.black;
            });
          },
        ),
        TextButton(
          child: Text(l10n.ok),
          onPressed: () {
            widget.onConfirm(_pickerColor ?? Colors.black);
          },
        ),
      ],
    );
  }
}
