import 'package:flutter/material.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

class TaskSaveDialog extends StatelessWidget {
  final Function onConfirm;
  final Function onCancel;

  TaskSaveDialog({required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).unsavedChangesTitle),
      content: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Text(AppLocalizations.of(context).unsavedChangesMessage),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text(AppLocalizations.of(context).dismiss),
          onPressed: () {
            onConfirm();
          },
        ),
        TextButton(
          child: Text(AppLocalizations.of(context).keepEditing),
          onPressed: () {
            onCancel();
          },
        ),
      ],
    );
  }
}
