import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

part 'external_link_opener.g.dart';

bool isWebLink(Uri? uri) =>
    uri != null &&
    (uri.scheme == 'http' || uri.scheme == 'https') &&
    uri.host.isNotEmpty;

/// The schemes besides http(s) that the web editor keeps as links and that
/// another app on the device may handle.
const systemLinkSchemes = {
  'ftp',
  'ftps',
  'mailto',
  'tel',
  'callto',
  'sms',
  'cid',
  'xmpp',
  'git',
  'obsidian',
  'notion',
  'message',
};

bool isSystemLink(Uri? uri) =>
    uri != null && systemLinkSchemes.contains(uri.scheme.toLowerCase());

/// Opens links that came from a server in the system browser, or in the
/// app that handles one of [systemLinkSchemes]. Anything else is refused,
/// so a server cannot trigger other app schemes. False when nothing could
/// open the link.
class ExternalLinkOpener {
  const new();

  Future<bool> open(Uri uri) async {
    if (!isWebLink(uri) && !isSystemLink(uri)) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException {
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
ExternalLinkOpener externalLinkOpener(Ref ref) => const ExternalLinkOpener();
