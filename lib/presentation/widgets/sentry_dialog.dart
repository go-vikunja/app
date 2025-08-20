import 'package:flutter/material.dart';

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
    return AlertDialog(
      title: Text('Enable automatic error reporting'),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            Text(
              'Would you like to help us improve Vikunja by sending error reports? Enabling this will send automatic error reports to the developers using Sentry.',
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text('Yes'),
          onPressed: () {
            onAccepts();
            Navigator.pop(context);
          },
        ),
        TextButton(
          child: Text('No'),
          onPressed: () {
            onRefuse();
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
