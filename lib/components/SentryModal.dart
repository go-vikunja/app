// show user modal that asks for consent to collect errors
import 'package:flutter/material.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/main.dart';

void showSentryModal(BuildContext context, VikunjaGlobalState global) {
  global.settingsManager.getSentryModalShown().then((sentryModalShown) {
    VikunjaGlobal.of(context).settingsManager.setSentryModalShown(true);
    if (!sentryModalShown) {
      return showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
                title: Text('Enable automatic error reporting'),
                content: SingleChildScrollView(
                  child: ListBody(
                    children: <Widget>[
                      Text(
                          'Would you like to help us improve Vikunja by sending error reports? Enabling this will send automatic error reports to the developers using Sentry.'),
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
