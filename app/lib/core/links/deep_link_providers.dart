import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/links/deep_link_relay.dart';
import 'package:vikunja_mobile/core/links/deep_link_source.dart';

part 'deep_link_providers.g.dart';

/// What the router feeds: it hands every pushed URI to `accept` first.
@Riverpod(keepAlive: true)
DeepLinkRelay deepLinkRelay(Ref ref) {
  final relay = DeepLinkRelay();
  ref.onDispose(() => unawaited(relay.dispose()));
  return relay;
}

/// Where the app takes deep links from; tests replace it with a fake.
@Riverpod(keepAlive: true)
DeepLinkSource deepLinkSource(Ref ref) => ref.watch(deepLinkRelayProvider);

/// Where the app takes the links of its home-screen widgets from; tests
/// replace it with a fake.
@Riverpod(keepAlive: true)
DeepLinkSource widgetLinkSource(Ref ref) =>
    ref.watch(deepLinkRelayProvider).widgetLinks;
