import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/account_security_repository.dart';
import 'package:vikunja_mobile/core/repositories/online/online_account_security_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

part 'account_security_repository_providers.g.dart';

@riverpod
AccountSecurityRepository accountSecurityRepositoryFor(
  Ref ref,
  String accountId,
) {
  final tokens = ref.watch(tokenStoreProvider);
  final sessions = ref.watch(sessionManagersProvider);
  return OnlineAccountSecurityRepository(
    port: ref.watch(accountSecurityPortProvider(accountId)),
    currentSessionId: () async {
      final stored = await tokens.read(accountId);
      if (stored == null) return null;
      // Only the refresh token survives a crash between the two writes; the
      // next access token carries the same sid.
      final accessToken = stored.accessToken.isEmpty
          ? await sessions.forAccount(accountId).validAccessToken()
          : stored.accessToken;
      return JwtClaims.tryParse(accessToken)?.sessionId;
    },
    now: ref.watch(clockProvider),
  );
}

/// The active account's; null while nobody is signed in.
@Riverpod(keepAlive: true)
AccountSecurityRepository? accountSecurityRepository(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  return ref.watch(accountSecurityRepositoryForProvider(accountId));
}
