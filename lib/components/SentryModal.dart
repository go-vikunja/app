// show user modal that asks for consent to collect errors
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/main.dart';

Future<void> showSentryModal(BuildContext context) {
  return VikunjaGlobal.of(context)
      .settingsManager
      .getSentryModalShown()
      .then((sentryModalShown) {
    VikunjaGlobal.of(context).settingsManager.setSentryModalShown(true);
    if (!sentryModalShown) {
      return showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
                title: Text('Error Reporting'),
                content: SingleChildScrollView(
                  child: ListBody(
                    children: <Widget>[
                      Text(
                          'Would you like to help us improve Vikunja by sending error reports?'),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    child: Text('Yes'),
                    onPressed: () {
                      VikunjaGlobal.of(context)
                          .settingsManager
                          .setSentryEnabled(true)
                          .then((_) => themeModel.notify());
                      Navigator.pop(context);
                    },
                  ),
                  TextButton(
                    child: Text('No'),
                    onPressed: () {
                      VikunjaGlobal.of(context)
                          .settingsManager
                          .setSentryEnabled(false)
                          .then((_) => themeModel.notify());
                      Navigator.pop(context);
                    },
                  ),
                ]);
          });
    }
  });
}
