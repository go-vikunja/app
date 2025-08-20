import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vikunja_app/domain/entities/bucket.dart';

class BucketLimitDialog extends StatelessWidget {
  final Bucket bucket;
  final _controller = TextEditingController();

  BucketLimitDialog({super.key, required this.bucket});

  @override
  Widget build(BuildContext context) {
    if (_controller.text.isEmpty) _controller.text = '${bucket.limit}';
    return AlertDialog(
      title: Text('Limit for \'${bucket.title}\''),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: 'Limit: ',
                    helperText: 'Set limit of 0 for no limit.',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onSubmitted: (text) =>
                      Navigator.of(context).pop(int.parse(text)),
                ),
              ),
              Column(
                children: <Widget>[
                  IconButton(
                    onPressed: () =>
                        _controller.text = '${int.parse(_controller.text) + 1}',
                    icon: Icon(Icons.expand_less),
                  ),
                  IconButton(
                    onPressed: () {
                      final limit = int.parse(_controller.text);
                      _controller.text = '${limit == 0 ? 0 : (limit - 1)}';
                    },
                    icon: Icon(Icons.expand_more),
                  ),
                ],
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
          onPressed: () => Navigator.of(context).pop(0),
          child: Text('Remove Limit'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(int.parse(_controller.text)),
          child: Text('Done'),
        ),
      ],
    );
  }
}
