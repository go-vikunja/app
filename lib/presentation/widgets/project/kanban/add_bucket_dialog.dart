import 'package:flutter/material.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

class AddBucketDialog extends StatelessWidget {
  final ValueChanged<String> onAdd;
  final TextEditingController textController = TextEditingController();

  AddBucketDialog({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.all(16.0),
      content: TextField(
        autofocus: true,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).newBucketName,
          hintText: AppLocalizations.of(context).bucketExample,
        ),
        controller: textController,
      ),
      actions: <Widget>[
        TextButton(
          child: Text(AppLocalizations.of(context).cancel),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: Text(AppLocalizations.of(context).add),
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
