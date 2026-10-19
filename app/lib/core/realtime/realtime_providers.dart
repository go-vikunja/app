import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';

part 'realtime_providers.g.dart';

/// Opens sockets with the app's `User-Agent`, never an `Origin`: the
/// server refuses an Origin it does not know.
@Riverpod(keepAlive: true)
RealtimeConnector realtimeConnector(Ref ref) => _IdentifiedConnector(
  const IoRealtimeConnector(),
  userAgent: ref.watch(clientIdentityProvider).userAgent,
);

final class _IdentifiedConnector implements RealtimeConnector {
  const new(this._inner, {required this._userAgent});

  final RealtimeConnector _inner;
  final String _userAgent;

  @override
  Future<RealtimeSocket> connect(
    Uri url, {
    Map<String, String> headers = const {},
  }) => _inner.connect(url, headers: {...headers, 'User-Agent': _userAgent});
}
