import 'package:flutter/material.dart';
import 'package:vikunja_app/core/utils/constants.dart';
import 'package:vikunja_app/domain/entities/version.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

enum VersionMismatchType { appTooOld, serverTooOld, unknown }

class VersionMismatchDialog extends StatelessWidget {
  final Version serverVersion;
  final VersionMismatchType mismatchType;

  const VersionMismatchDialog({
    super.key,
    required this.serverVersion,
    this.mismatchType = VersionMismatchType.unknown,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.versionDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_descriptionText(l10n)),
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                l10n.versionDialogAppVersion(appBuiltForVersion.toString()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(l10n.versionDialogUsed(serverVersion.toString())),
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

  String _descriptionText(AppLocalizations l10n) {
    switch (mismatchType) {
      case VersionMismatchType.appTooOld:
        return l10n.versionDialogAppTooOld;
      case VersionMismatchType.serverTooOld:
        return l10n.versionDialogServerTooOld;
      case VersionMismatchType.unknown:
        return l10n.versionDialogDescription;
    }
  }
}
