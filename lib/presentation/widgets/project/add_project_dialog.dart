import 'package:flutter/material.dart';

class AddProjectDialog extends StatefulWidget {
  final ValueChanged<String>? onAdd;
  final InputDecoration? decoration;

  const AddProjectDialog({Key? key, this.onAdd, this.decoration})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => AddDialogState();
}

class AddDialogState extends State<AddProjectDialog> {
  DateTime? customDueDate;
  var textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return new AlertDialog(
      contentPadding: const EdgeInsets.all(16.0),
      content: new Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: <Widget>[
          Expanded(
            child: new TextField(
              autofocus: true,
              decoration: widget.decoration,
              controller: textController,
            ),
          ),
        ]),
      ]),
      actions: <Widget>[
        new TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        new TextButton(
          child: const Text('Add'),
          onPressed: () {
            if (widget.onAdd != null && textController.text.isNotEmpty)
              widget.onAdd!(textController.text);
            Navigator.pop(context);
          },
        )
      ],
    );
  }
}
