import 'package:flutter/material.dart';
import 'package:vikunja_app/models/label.dart';
import 'package:vikunja_app/theme/constants.dart';

class LabelComponent extends StatefulWidget {
  final Label label;
  final VoidCallback onDelete;

  const LabelComponent({Key? key, required this.label, required this.onDelete})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return new LabelComponentState();
  }
}

class LabelComponentState extends State<LabelComponent> {
  @override
  Widget build(BuildContext context) {
    Color backgroundColor = widget.label.color ?? vLabelDefaultColor;
    Color textColor =
        backgroundColor.computeLuminance() > 0.5 ? vLabelDark : vLabelLight;

    return Chip(
      label: Text(
        widget.label.title ?? "",
        style: TextStyle(
          color: textColor,
        ),
      ),
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(3)),
      ),
      onDeleted: widget.onDelete,
      deleteIconColor: textColor,
      deleteIcon: Container(
        padding: EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Color.fromARGB(50, 0, 0, 0),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.close,
          color: textColor,
          size: 15,
        ),
      ),
    );
  }
}
