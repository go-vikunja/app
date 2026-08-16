import 'package:flutter/material.dart';
import 'package:vikunja_app/core/network/keychain_alias.dart' as keychain;
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

/// Shown when the login screen detects the server requires a client
/// certificate (see [isCertificateRequiredError] in
/// `lib/core/utils/network.dart`). Resolves to the chosen Android Keystore
/// alias, or `null` if the user declined, dismissed the dialog, or backed
/// out of the system certificate picker.
class ClientCertRequiredDialog extends StatelessWidget {
  final Future<String?> Function()? chooseClientCertificate;

  const ClientCertRequiredDialog({super.key, this.chooseClientCertificate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.clientCertRequiredDialogTitle),
      content: Text(l10n.clientCertRequiredDialogBody),
      actions: <Widget>[
        TextButton(
          child: Text(l10n.clientCertRequiredDialogNotNow),
          onPressed: () => Navigator.pop(context, null),
        ),
        FilledButton(
          child: Text(l10n.clientCertRequiredDialogSelect),
          onPressed: () async {
            final alias =
                await (chooseClientCertificate?.call() ??
                    keychain.choosePrivateKeyAlias());
            if (context.mounted) {
              Navigator.pop(context, alias);
            }
          },
        ),
      ],
    );
  }
}
