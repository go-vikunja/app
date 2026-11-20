import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/link_share_store.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';

final _log = Logger('AccountsWithoutTokens');

/// How long secure storage may refuse an account's tokens before the
/// account is asked to sign in again.
const unreadableTokensGrace = Duration(hours: 24);

/// The registry and secure storage are written separately, so a crash between
/// the writes, or a backup restore without the Keychain/Keystore, leaves an
/// account without tokens. It is marked `needsReauth` like an account whose
/// session ended, so it keeps its local data and offers "Sign in again". A
/// guest counts as signed in while its link's hash is stored.
///
/// Tokens that cannot be read are not missing: the Keychain refuses reads
/// before the first unlock, and a Keystore failure can pass. Only when
/// reads keep failing for [unreadableTokensGrace] with no good read in
/// between, here or by a session manager (a key the system lost for good),
/// is the account asked to sign in again. For the app's start only.
Future<AccountRegistryState> flagAccountsWithoutTokens(
  AccountRegistry registry,
  TokenStore tokenStore,
  LinkShareStore linkShareStore, {
  SessionDiagnostics? diagnostics,
  DateTime Function() clock = DateTime.now,
}) async {
  var state = await registry.load();
  for (final entry in state.accounts) {
    if (entry.account.needsReauth) continue;
    final Object? secrets;
    try {
      secrets = entry.account.isLinkShare
          ? await linkShareStore.read(entry.id)
          : await tokenStore.read(entry.id);
    } on Object catch (error) {
      _log.warning(
        'Could not read the tokens of account ${entry.id}: '
        '${error.runtimeType}',
      );
      final now = clock();
      final since = await diagnostics?.noteUnreadable(entry.id, now);
      if (since == null || now.difference(since) < unreadableTokensGrace) {
        continue;
      }
      state = await _flag(
        registry,
        diagnostics,
        entry.id,
        SessionEndCause.storageUnreadable,
        now,
      );
      continue;
    }
    await diagnostics?.noteReadable(entry.id);
    if (secrets != null) continue;
    _log.warning('Account ${entry.id} has no tokens, it needs a new sign-in');
    state = await _flag(
      registry,
      diagnostics,
      entry.id,
      SessionEndCause.missingTokens,
      clock(),
    );
  }
  return state;
}

Future<AccountRegistryState> _flag(
  AccountRegistry registry,
  SessionDiagnostics? diagnostics,
  String accountId,
  SessionEndCause cause,
  DateTime at,
) async {
  await diagnostics?.recordEnd(
    accountId,
    SessionEndDiagnosis(at: at, cause: cause, part: AppPart.app),
  );
  return await registry.markNeedsReauth(accountId);
}
