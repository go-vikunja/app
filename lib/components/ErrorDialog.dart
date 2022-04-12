import 'package:flutter/material.dart';

class ErrorDialog extends StatelessWidget {
  final dynamic error;

  ErrorDialog({this.error});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Text(error.toString()),
      actions: <Widget>[
        TextButton(
          child: Text('Close'),
          onPressed: () => Navigator.of(context).maybePop(),
        )
      ],
    );
  }
}
