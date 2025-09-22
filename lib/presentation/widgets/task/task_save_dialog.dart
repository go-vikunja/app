import 'package:flutter/material.dart';

class TaskSaveDialog extends StatelessWidget {
  final Function onConfirm;
  final Function onCancel;

  TaskSaveDialog({required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('You have unsaved changes!'),
      content: SingleChildScrollView(
        child: Column(
          children: <Widget>[Text('Would you like to dismiss those changes?')],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text('Dismiss'),
          onPressed: () {
            onConfirm();
          },
        ),
        TextButton(
          child: Text('Keep editing'),
          onPressed: () {
            onCancel();
          },
        ),
      ],
    );
  }
}
