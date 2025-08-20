import 'package:flutter/material.dart';
import 'package:vikunja_app/domain/entities/bucket.dart';

class ChangeTitleDialog extends StatelessWidget {
  final Bucket bucket;
  final TextEditingController _controller;

  ChangeTitleDialog({super.key, required this.bucket})
    : _controller = TextEditingController(text: bucket.title);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Change the title of \'${bucket.title}\''),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(labelText: 'Enter title'),
                  onSubmitted: (text) => Navigator.of(context).pop(text),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: <TextButton>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text('Done'),
        ),
      ],
    );
  }
}
