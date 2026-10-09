import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

part 'external_link_opener.g.dart';

bool isWebLink(Uri? uri) =>
    uri != null &&
    (uri.scheme == 'http' || uri.scheme == 'https') &&
    uri.host.isNotEmpty;

/// Opens links that came from a server in the system browser. Anything that
/// is not http(s) is refused, so a server cannot trigger other app schemes.
class ExternalLinkOpener {
  const new();

  Future<bool> open(Uri uri) async {
    if (!isWebLink(uri)) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException {
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
ExternalLinkOpener externalLinkOpener(Ref ref) => const ExternalLinkOpener();
