import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/presentation/manager/settings_controller.dart';

void showSentryModal(
    BuildContext context, WidgetRef ref, VikunjaGlobalState global) {
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
                      ref
                          .read(settingsControllerProvider.notifier)
                          .setSentryEnabled(true);
                      Navigator.pop(context);
                    },
                  ),
                  TextButton(
                    child: Text('No'),
                    onPressed: () {
                      ref
                          .read(settingsControllerProvider.notifier)
                          .setSentryEnabled(false);
                      Navigator.pop(context);
                    },
                  ),
                ]);
          });
    }
  });
}
