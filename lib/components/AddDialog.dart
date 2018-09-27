import 'package:flutter/material.dart';

class AddDialog extends StatelessWidget {
  final ValueChanged<String> onAdd;
  final InputDecoration decoration;

  const AddDialog({Key key, this.onAdd, this.decoration}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var textController = TextEditingController();
    return new AlertDialog(
      contentPadding: const EdgeInsets.all(16.0),
      content: new Row(children: <Widget>[
        Expanded(
          child: new TextField(
            autofocus: true,
            decoration: this.decoration,
            controller: textController,
          ),
        )
      ]),
      actions: <Widget>[
        new FlatButton(
          child: const Text('CANCEL'),
          onPressed: () => Navigator.pop(context),
        ),
        new FlatButton(
          child: const Text('ADD'),
          onPressed: () {
            if (this.onAdd != null && textController.text.isNotEmpty)
              this.onAdd(textController.text);
            Navigator.pop(context);
          },
        )
      ],
    );
  }
}
