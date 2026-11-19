import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';

final _log = Logger('PlatformNetwork');

/// What Android gives Cronet and dart:io does not see: the CAs the user or
/// a device policy installed, which the app's network security config
/// trusts for every server (R8), and the proxy the system picks for an
/// address.
typedef PlatformNetworkSettings = ({List<String> userCaPems, String proxy});

abstract interface class PlatformNetwork {
  Future<PlatformNetworkSettings> settingsFor(Uri url);
}

/// Through the device channel, on the UI engine only, where the realtime
/// socket runs.
final class AndroidPlatformNetwork implements PlatformNetwork {
  const new();

  @override
  Future<PlatformNetworkSettings> settingsFor(Uri url) async {
    final pems = await deviceChannel.invokeListMethod<String>(
      'userCaCertificates',
    );
    final proxy = await deviceChannel.invokeMethod<String>('proxyFor', {
      'url': url.toString(),
    });
    return (userCaPems: pems ?? const [], proxy: proxy ?? 'DIRECT');
  }
}

/// The client for a server without TLS settings of its own: the system's
/// roots plus [settings]' user CAs, and the system's proxy. A CA dart:io
/// cannot read is left out.
HttpClient platformHttpClient(PlatformNetworkSettings settings) {
  final context = SecurityContext(withTrustedRoots: true);
  for (final pem in settings.userCaPems) {
    try {
      context.setTrustedCertificatesBytes(utf8.encode(pem));
    } on TlsException catch (error) {
      _log.info('A user CA was left out: ${error.runtimeType}');
    }
  }
  return HttpClient(context: context)..findProxy = (_) => settings.proxy;
}

/// The URL the proxy is chosen for: the socket's handshake is an HTTP
/// request to the same host.
@visibleForTesting
Uri handshakeUrl(Uri socketUrl) =>
    socketUrl.replace(scheme: socketUrl.isScheme('wss') ? 'https' : 'http');

/// Null where the platform needs nothing beyond dart:io's defaults.
PlatformNetwork? platformNetworkFor(TargetPlatform platform) =>
    platform == TargetPlatform.android ? const AndroidPlatformNetwork() : null;

/// Never fails the connection: without the settings the socket tries as
/// before.
Future<PlatformNetworkSettings?> readPlatformNetwork(
  PlatformNetwork? network,
  Uri socketUrl,
) async {
  if (network == null) return null;
  try {
    return await network.settingsFor(handshakeUrl(socketUrl));
  } on Object catch (error) {
    // Also an engine without the channel, or without a binding.
    _log.info('No platform network settings: ${error.runtimeType}');
    return null;
  }
}
