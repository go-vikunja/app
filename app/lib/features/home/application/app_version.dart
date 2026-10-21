import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';

part 'app_version.g.dart';

typedef AppVersion = ({String version, String build});

/// The app's version and build number, as it reports itself to servers.
@Riverpod(keepAlive: true)
AppVersion appVersion(Ref ref) {
  final identity = ref.watch(clientIdentityProvider);
  return (version: identity.appVersion, build: identity.buildNumber);
}
