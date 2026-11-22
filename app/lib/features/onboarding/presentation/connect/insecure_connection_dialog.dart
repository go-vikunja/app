import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_dialog_action.dart';
import 'package:vikunja_mobile/core/text/server_address_display.dart';

/// With [httpsFailed] the question says that https did not answer, which
/// is what blocking it on the network looks like, rather than that the
/// server uses http. It comes every time (decision log: Connections).
/// For a server on the home network, where plain http is common, it says so and
/// how to type the address so that the app goes to http at once.
Future<bool> confirmInsecureConnection(
  BuildContext context, {
  required Uri rootUri,
  bool httpsFailed = false,
}) async {
  final l10n = context.l10n;
  final host = displayHost(rootUri);
  final accepted = await showAdaptiveDialog<bool>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      scrollable: true,
      title: Text(
        httpsFailed
            ? l10n.insecureFallbackDialogTitle
            : l10n.insecureDialogTitle,
      ),
      content: Text(switch (httpsFailed) {
        false => l10n.insecureDialogBody(host),
        true when isLocalNetworkHost(rootUri.host) =>
          l10n.insecureFallbackDialogBodyLocal(host),
        true => l10n.insecureFallbackDialogBody(host),
      }),
      actions: [
        AdaptiveDialogAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.insecureDialogCancel),
        ),
        AdaptiveDialogAction(
          onPressed: () => Navigator.of(context).pop(true),
          isDestructive: true,
          child: Text(l10n.insecureDialogContinue),
        ),
      ],
    ),
  );
  return accepted ?? false;
}

/// Whether [host] is this device or on a home network: a loopback, private
/// or link-local IP address, `localhost`, or a name under `.local`,
/// `.home.arpa` or `.internal`, which only local networks resolve.
bool isLocalNetworkHost(String host) {
  final name = host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  const localNames = ['.localhost', '.local', '.home.arpa', '.internal'];
  if (name == 'localhost' || localNames.any(name.endsWith)) return true;
  final address = InternetAddress.tryParse(name);
  if (address == null) return false;
  if (address.isLoopback || address.isLinkLocal) return true;
  final bytes = address.rawAddress;
  return switch (address.type) {
    InternetAddressType.IPv4 =>
      bytes[0] == 10 ||
          (bytes[0] == 172 && bytes[1] & 0xF0 == 16) ||
          (bytes[0] == 192 && bytes[1] == 168),
    InternetAddressType.IPv6 => bytes[0] & 0xFE == 0xFC,
    _ => false,
  };
}
