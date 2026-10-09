import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/logging/redaction.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/features/onboarding/application/connect_server_state.dart';
import 'package:vikunja_mobile/features/onboarding/application/current_server.dart';

export 'package:vikunja_mobile/features/onboarding/application/connect_server_state.dart';

part 'connect_server_controller.g.dart';

const publicDemoAddress = 'https://try.vikunja.io';

final _log = Logger('ConnectServer');

@riverpod
class ConnectServerController extends _$ConnectServerController {
  CancelToken? _cancelToken;

  @override
  ConnectServerState build() {
    ref.onDispose(() => _cancelToken?.cancel());
    return const ConnectServerIdle();
  }

  Future<void> connect(String input) async {
    if (state is ConnectServerConnecting) return;
    final cancelToken = _cancelToken = CancelToken();
    ref.read(currentServerProvider.notifier).clear();
    state = ConnectServerConnecting(input);

    final outcome = await _probe(input, cancelToken);
    if (!ref.mounted || cancelToken.isCancelled) return;
    _cancelToken = null;
    _apply(outcome);
  }

  Future<ConnectServerState> _probe(
    String input,
    CancelToken cancelToken,
  ) async {
    try {
      final connection = await ref
          .read(serverConnectorProvider)
          .connect(input, cancelToken: cancelToken);
      return connection.isInsecure
          ? ConnectServerAwaitingInsecureConsent(connection)
          : ConnectServerConnected(connection);
    } on ServerConnectionFailure catch (failure) {
      return ConnectServerFailed(input: input, failure: failure);
    } on Object catch (error, stackTrace) {
      if (!cancelToken.isCancelled) {
        _log.severe(
          'Unexpected connect failure: ${redactSecrets('$error')}',
          null,
          stackTrace,
        );
      }
      return ConnectServerFailed(input: input);
    }
  }

  void cancel() {
    final cancelToken = _cancelToken;
    if (cancelToken == null) return;
    _cancelToken = null;
    cancelToken.cancel();
    state = const ConnectServerIdle();
  }

  void acceptInsecureConnection() {
    if (state case ConnectServerAwaitingInsecureConsent(:final connection)) {
      _apply(ConnectServerConnected(connection));
    }
  }

  void declineInsecureConnection() {
    if (state is ConnectServerAwaitingInsecureConsent) reset();
  }

  void reset() {
    if (state is ConnectServerConnecting) return;
    state = const ConnectServerIdle();
  }

  void _apply(ConnectServerState next) {
    if (next is ConnectServerConnected) {
      ref.read(currentServerProvider.notifier).select(next.connection);
    }
    state = next;
  }
}
