import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/share/channel_share_intent_source.dart';
import 'package:vikunja_mobile/core/share/share_intent_source.dart';

part 'share_providers.g.dart';

/// Shares from other apps; iOS gets its share extension in the iOS phase
/// and has none until then.
@Riverpod(keepAlive: true)
ShareIntentSource shareIntentSource(Ref ref) {
  if (!Platform.isAndroid) return const NoShareIntentSource();
  final source = ChannelShareIntentSource();
  ref.onDispose(source.dispose);
  return source;
}

final class NoShareIntentSource implements ShareIntentSource {
  const new();

  @override
  Future<IncomingShare?> pending() async => null;

  @override
  Stream<IncomingShare> get shares => const Stream.empty();

  @override
  Future<CopiedSharedFile> copy(String uri, {required int maxBytes}) =>
      Future.error(const SharedFileUnreadable());

  @override
  Future<void> clear() async {}
}
