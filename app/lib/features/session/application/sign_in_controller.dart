import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/browser_sign_in.dart';
import 'package:vikunja_mobile/core/auth/web_authenticator.dart';
import 'package:vikunja_mobile/core/db/account_database_files.dart';
import 'package:vikunja_mobile/core/db/open_account_database.dart';
import 'package:vikunja_mobile/core/logging/redaction.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/features/session/application/session_check.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_hosts.dart';

part 'sign_in_controller.g.dart';

final _log = Logger('SignIn');

@immutable
sealed class SignInState {
  const new();
}

final class SignInIdle extends SignInState {
  const new();
}

/// Waiting, before the browser opens, for an account signed out a moment
/// ago whose data part of the app still holds; leaving drops the sign-in
/// ([SignInController.reset]).
final class SignInSettling extends SignInState {
  const new();
}

final class SignInInProgress extends SignInState {
  const new();
}

final class SignInFailed extends SignInState {
  const new(this.error, {required this.serverRoot});

  /// A `VikunjaFailure`, `ServerConnectionFailure`,
  /// `AuthorizationCallbackException`, `WebAuthenticationFailed`,
  /// `SignedInAsDifferentUser`, `SignOutStillFinishing` or anything
  /// unexpected.
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

/// What the user is asked right before the browser opens the sign-in page.
@immutable
final class BrowserLeg {
  const new(this.connection, {this.otherHost});

  final ServerConnection connection;

  /// The sign-in page's host, when it is not the server's and the account
  /// has not signed in there yet after confirming it; always for an account
  /// being added, which is not known before the browser returns.
  final OtherSignInHost? otherHost;
}

/// False ends the sign-in before the browser opens.
typedef ConfirmBrowserLeg = Future<bool> Function(BrowserLeg leg);

@riverpod
class SignInController extends _$SignInController {
  @override
  SignInState build() => const SignInIdle();

  var _settles = 0;

  /// [confirm] is asked before the browser opens, while the state is still
  /// idle.
  Future<void> signIn(
    ServerConnection connection, {
    required ConfirmBrowserLeg confirm,
  }) async {
    if (state is SignInInProgress || state is SignInSettling) return;
    final registry = ref.read(accountRegistryProvider);
    final browserSignIn = ref.read(browserSignInProvider);
    final hosts = ConfirmedSignInHosts(ref.read(preferencesStoreProvider));
    final files = ref.read(accountDatabaseFilesProvider);
    final container = ref.container;
    final otherHost = otherSignInHost(connection);
    final confirmed = await confirm(
      BrowserLeg(connection, otherHost: otherHost),
    );
    if (!confirmed || !ref.mounted) return;
    if (hasSignOutLeftovers && !await _settle(connection.rootUri, files)) {
      return;
    }
    return await _run(connection.rootUri, () async {
      final known = await registry.load();
      final account = await browserSignIn.signIn(
        connection,
        // Added again, the account becomes active at once, like a switch.
        beforeActivatingExisting: (accountId) =>
            prepareSyncStatus(container, accountId),
      );
      if (account == null) return null;
      await hosts.signedIn(account.id, otherHost);
      return SignInSucceeded(
        account,
        isNewAccount: known.find(account.id) == null,
        wasActive: known.activeAccountId == account.id,
      );
    });
  }

  /// For an account whose session ended; another user is refused. The
  /// server is negotiated again first, because it may have been updated
  /// since the account was added; [confirm] is asked about the page the
  /// new negotiation gives, while the state is in progress.
  Future<void> signInAgain(
    RegisteredAccount entry, {
    required ConfirmBrowserLeg confirm,
  }) {
    final registry = ref.read(accountRegistryProvider);
    final browserSignIn = ref.read(browserSignInProvider);
    final hosts = ConfirmedSignInHosts(ref.read(preferencesStoreProvider));
    final files = ref.read(accountDatabaseFilesProvider);
    return _run(entry.connection.rootUri, () async {
      // A stale entry of an account signed out meanwhile would otherwise
      // be registered again onto a database that is still closing.
      await settleSignedOutDatabases(files, accountId: entry.id);
      final known = await registry.load();
      final connection = await _renegotiate(entry.connection);
      final otherHost = otherSignInHost(connection);
      final ask =
          otherHost != null && !await hosts.isConfirmed(entry.id, otherHost);
      final confirmed = await confirm(
        BrowserLeg(connection, otherHost: ask ? otherHost : null),
      );
      if (!confirmed) return null;
      final account = await browserSignIn.signIn(
        connection,
        expectedAccount: entry.account,
      );
      if (account == null) return null;
      await hosts.signedIn(account.id, otherHost);
      return SignInSucceeded(
        account,
        isNewAccount: false,
        wasActive: known.activeAccountId == account.id,
      );
    });
  }

  void reset() {
    if (state is! SignInInProgress) state = const SignInIdle();
  }

  /// True to go on to the browser: the wait is over and nobody left or
  /// started another sign-in meanwhile.
  Future<bool> _settle(Uri serverRoot, AccountDatabaseFiles files) async {
    final settle = ++_settles;
    state = const SignInSettling();
    bool current() =>
        ref.mounted && state is SignInSettling && settle == _settles;
    try {
      // The account is known only once the browser returns, so any leftover
      // could be it.
      await settleSignedOutDatabases(files);
    } on Object catch (error, stackTrace) {
      final failed = _failed(error, stackTrace, serverRoot);
      if (current()) state = failed;
      return false;
    }
    return current();
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
      next = _failed(error, stackTrace, serverRoot);
    }
    if (ref.mounted) state = next;
  }

  SignInFailed _failed(Object error, StackTrace stackTrace, Uri serverRoot) {
    if (_isExpected(error)) {
      _log.info('Sign-in failed: $error');
    } else {
      _log.severe(
        'Unexpected sign-in failure: ${redactSecrets('$error')}',
        null,
        stackTrace,
      );
    }
    return SignInFailed(error, serverRoot: serverRoot);
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
      error is SignedInAsDifferentUser ||
      error is SignOutStillFinishing;
}
