import 'package:flutter/material.dart';
import 'package:vikunja_app/core/utils/constants.dart';
import 'package:vikunja_app/domain/entities/version.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

class VersionMismatchDialog extends StatelessWidget {
  final Version serverVersion;

  const VersionMismatchDialog({super.key, required this.serverVersion});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(AppLocalizations.of(context).versionDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).versionDialogDescription),
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                AppLocalizations.of(
                  context,
                ).versionDialogSupported(supportedServerVersion.toString()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                AppLocalizations.of(
                  context,
                ).versionDialogUsed(serverVersion.toString()),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text(l10n.ok),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
