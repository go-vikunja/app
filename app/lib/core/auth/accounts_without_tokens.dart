import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';

final _log = Logger('AccountsWithoutTokens');

/// The registry and secure storage are written separately, so a crash between
/// the writes, or a backup restore without the Keychain/Keystore, leaves an
/// account without tokens. It is marked `needsReauth` like an account whose
/// session ended, so it keeps its local data and offers "Sign in again".
Future<AccountRegistryState> flagAccountsWithoutTokens(
  AccountRegistry registry,
  TokenStore tokenStore,
) async {
  var state = await registry.load();
  for (final entry in state.accounts) {
    if (entry.account.needsReauth) continue;
    final StoredTokens? tokens;
    try {
      tokens = await tokenStore.read(entry.id);
    } on Object catch (error) {
      // Unreadable is not missing: the Keychain refuses reads before the
      // first unlock, and the session manager handles a real loss on use.
      _log.warning(
        'Could not read the tokens of account ${entry.id}: '
        '${error.runtimeType}',
      );
      continue;
    }
    if (tokens != null) continue;
    _log.warning('Account ${entry.id} has no tokens, it needs a new sign-in');
    state = await registry.markNeedsReauth(entry.id);
  }
  return state;
}
