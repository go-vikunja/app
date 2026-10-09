import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/browser_sign_in.dart';
import 'package:vikunja_mobile/core/auth/web_authenticator.dart';
import 'package:vikunja_mobile/core/logging/redaction.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/features/session/application/session_check.dart';

part 'sign_in_controller.g.dart';

final _log = Logger('SignIn');

@immutable
sealed class SignInState {
  const new();
}

final class SignInIdle extends SignInState {
  const new();
}

final class SignInInProgress extends SignInState {
  const new();
}

final class SignInFailed extends SignInState {
  const new(this.error, {required this.serverRoot});

  /// A `VikunjaFailure`, `ServerConnectionFailure`,
  /// `AuthorizationCallbackException`, `WebAuthenticationFailed`,
  /// `SignedInAsDifferentUser` or anything unexpected.
  final Object error;
  final Uri serverRoot;
}

final class SignInSucceeded extends SignInState {
  const new(this.account);

  final RegisteredAccount account;
}

@riverpod
class SignInController extends _$SignInController {
  @override
  SignInState build() => const SignInIdle();

  Future<void> signIn(ServerConnection connection) => _run(
    connection.rootUri,
    () => ref.read(browserSignInProvider).signIn(connection),
  );

  /// For an account whose session ended; another user is refused. The
  /// server is negotiated again first, because it may have been updated
  /// since the account was added.
  Future<void> signInAgain(RegisteredAccount entry) =>
      _run(entry.connection.rootUri, () async {
        final connection = await _renegotiate(entry.connection);
        return await ref
            .read(browserSignInProvider)
            .signIn(connection, expectedAccount: entry.account);
      });

  void reset() {
    if (state is! SignInInProgress) state = const SignInIdle();
  }

  Future<void> _run(
    Uri serverRoot,
    Future<RegisteredAccount?> Function() signIn,
  ) async {
    if (state is SignInInProgress) return;
    state = const SignInInProgress();
    SignInState next;
    try {
      final account = await signIn();
      if (account != null && ref.mounted) {
        ref.read(sessionCheckProvider).noteVerified(account.id);
      }
      next = account == null ? const SignInIdle() : SignInSucceeded(account);
    } on Object catch (error, stackTrace) {
      if (_isExpected(error)) {
        _log.info('Sign-in failed: $error');
      } else {
        _log.severe(
          'Unexpected sign-in failure: ${redactSecrets('$error')}',
          null,
          stackTrace,
        );
      }
      next = SignInFailed(error, serverRoot: serverRoot);
    }
    if (ref.mounted) state = next;
  }

  Future<ServerConnection> _renegotiate(ServerConnection stored) async {
    final ServerConnection fresh;
    try {
      fresh = await ref
          .read(serverConnectorProvider)
          .connect(stored.rootUri.toString());
    } on ServerConnectionFailure {
      rethrow;
    } on Object catch (error) {
      _log.warning(
        'Re-negotiation failed, using the stored connection: '
        '${error.runtimeType}',
      );
      return stored;
    }
    // A different root would be a different account.
    final usable =
        fresh.rootUri == stored.rootUri && fresh.capabilities.isSupported;
    return usable ? fresh : stored;
  }

  static bool _isExpected(Object error) =>
      error is VikunjaFailure ||
      error is ServerConnectionFailure ||
      error is AuthorizationCallbackException ||
      error is WebAuthenticationFailed ||
      error is SignedInAsDifferentUser;
}
