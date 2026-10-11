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
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
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
  const new(
    this.account, {
    required this.isNewAccount,
    required this.wasActive,
  });

  final RegisteredAccount account;

  /// False when the account was on this device before, e.g. added again by
  /// mistake: the sign-in only switched to it.
  final bool isNewAccount;

  /// The account was the active one already, so nothing switched; only its
  /// session was replaced.
  final bool wasActive;
}

@riverpod
class SignInController extends _$SignInController {
  @override
  SignInState build() => const SignInIdle();

  Future<void> signIn(ServerConnection connection) {
    final registry = ref.read(accountRegistryProvider);
    final browserSignIn = ref.read(browserSignInProvider);
    final container = ref.container;
    return _run(connection.rootUri, () async {
      final known = await registry.load();
      final account = await browserSignIn.signIn(
        connection,
        // Added again, the account becomes active at once, like a switch.
        beforeActivatingExisting: (accountId) =>
            prepareSyncStatus(container, accountId),
      );
      if (account == null) return null;
      return SignInSucceeded(
        account,
        isNewAccount: known.find(account.id) == null,
        wasActive: known.activeAccountId == account.id,
      );
    });
  }

  /// For an account whose session ended; another user is refused. The
  /// server is negotiated again first, because it may have been updated
  /// since the account was added.
  Future<void> signInAgain(RegisteredAccount entry) {
    final registry = ref.read(accountRegistryProvider);
    return _run(entry.connection.rootUri, () async {
      final known = await registry.load();
      final connection = await _renegotiate(entry.connection);
      final account = await ref
          .read(browserSignInProvider)
          .signIn(connection, expectedAccount: entry.account);
      return account == null
          ? null
          : SignInSucceeded(
              account,
              isNewAccount: false,
              wasActive: known.activeAccountId == account.id,
            );
    });
  }

  void reset() {
    if (state is! SignInInProgress) state = const SignInIdle();
  }

  Future<void> _run(
    Uri serverRoot,
    Future<SignInSucceeded?> Function() signIn,
  ) async {
    if (state is SignInInProgress) return;
    state = const SignInInProgress();
    SignInState next;
    try {
      final succeeded = await signIn();
      if (succeeded != null && ref.mounted) {
        ref.read(sessionCheckProvider).noteVerified(succeeded.account.id);
      }
      next = succeeded ?? const SignInIdle();
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
