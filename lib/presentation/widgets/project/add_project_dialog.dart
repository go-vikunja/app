import 'package:flutter/material.dart';

class AddProjectDialog extends StatelessWidget {
  final ValueChanged<String> onAdd;
  final TextEditingController textController = TextEditingController();

  AddProjectDialog({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.all(16.0),
      content: TextField(
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Project',
          hintText: 'eg. Personal Project',
        ),
        controller: textController,
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: const Text('Add'),
          onPressed: () {
            if (textController.text.isNotEmpty) {
              onAdd(textController.text);
            }
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
