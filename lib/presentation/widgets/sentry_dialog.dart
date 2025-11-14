import 'package:flutter/material.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

class SentryDialog extends StatelessWidget {
  final Function onAccepts;
  final Function onRefuse;

  const SentryDialog({
    super.key,
    required this.onAccepts,
    required this.onRefuse,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.sentryDialogTitle),
      content: SingleChildScrollView(
        child: ListBody(children: <Widget>[Text(l10n.sentryDialogMessage)]),
      ),
      actions: <Widget>[
        TextButton(
          child: Text(l10n.yes),
          onPressed: () {
            onAccepts();
            Navigator.pop(context);
          },
        ),
        TextButton(
          child: Text(l10n.no),
          onPressed: () {
            onRefuse();
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
