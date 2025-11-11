import 'package:flutter/material.dart';
import 'package:vikunja_app/domain/entities/bucket.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

class ChangeTitleDialog extends StatelessWidget {
  final Bucket bucket;
  final TextEditingController _controller;

  ChangeTitleDialog({super.key, required this.bucket})
    : _controller = TextEditingController(text: bucket.title);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.changeBucketTitle(bucket.title)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(labelText: l10n.enterTitle),
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
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.done),
        ),
      ],
    );
  }
}
