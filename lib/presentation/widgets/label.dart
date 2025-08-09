import 'package:flutter/material.dart';
import 'package:vikunja_app/data/models/label.dart';

class LabelComponent extends StatelessWidget {
  final Label label;
  final VoidCallback? onDelete;

  const LabelComponent({Key? key, required this.label, this.onDelete})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        label.title,
        style: TextStyle(
          color: label.textColor,
        ),
      ),
      backgroundColor: label.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
        side: BorderSide(style: BorderStyle.none),
      ),
      onDeleted: onDelete,
      deleteIconColor: label.textColor,
      deleteIcon: Container(
        padding: EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Color.fromARGB(50, 0, 0, 0),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.close,
          color: label.textColor,
          size: 15,
        ),
      ),
    );
  }
}
