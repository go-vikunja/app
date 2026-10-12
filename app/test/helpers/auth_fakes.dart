import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/misc.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_gateways.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/auth/server_clock_offsets.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/auth/web_authenticator.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/core/storage/secure_store.dart';
import 'package:vikunja_mobile/features/notifications/application/notifications_onboarding.dart';

final class MemorySecureStore implements SecureStore {
  final Map<String, String> values = {};

  /// `write <key>` and `delete <key>`, in order.
  final List<String> operations = [];

  /// Lets a test hold a write open, e.g. to check that nothing uses a token
  /// before it is stored, or make it fail by throwing.
  Future<void> Function(String key)? beforeWrite;

  /// Lets a test hold a delete open, e.g. in the middle of a sign-out.
  Future<void> Function(String key)? beforeDelete;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    await beforeWrite?.call(key);
    operations.add('write $key');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    await beforeDelete?.call(key);
    operations.add('delete $key');
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    operations.add('deleteAll');
    values.clear();
  }
}

final class MemoryPreferencesStore implements PreferencesStore {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

var _tokenCounter = 0;

String fakeJwt({
  required int userId,
  required String username,
  required String sessionId,
  required DateTime issuedAt,
  required DateTime expiresAt,
}) {
  String encode(Map<String, Object?> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return [
    encode({'alg': 'HS256', 'typ': 'JWT'}),
    encode({
      'type': 1,
      'id': userId,
      'username': username,
      'is_admin': false,
      'iat': issuedAt.millisecondsSinceEpoch ~/ 1000,
      'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
      'sid': sessionId,
      'jti': 'jti-${++_tokenCounter}',
    }),
    'c2lnbmF0dXJl',
  ].join('.');
}

/// A token response as the server would issue it at [issuedAt] (server time).
TokenSet issueTokens({
  required DateTime issuedAt,
  int userId = 7,
  String username = 'alice',
  String sessionId = 'session-1',
  Duration lifetime = const Duration(minutes: 10),
  String? refreshToken,
}) {
  final expiresAt = issuedAt.add(lifetime);
  return TokenSet(
    accessToken: fakeJwt(
      userId: userId,
      username: username,
      sessionId: sessionId,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
    ),
    refreshToken: refreshToken ?? 'refresh-${++_tokenCounter}',
    accessTokenExpiry: expiresAt,
    issuedAt: issuedAt,
    sessionId: sessionId,
    userId: userId,
    username: username,
  );
}

final class FakeTokenGateway implements TokenGateway {
  Future<TokenSet> Function(String code)? onExchange;
  Future<TokenSet> Function(String refreshToken)? onRefresh;
  final List<String> exchangedCodes = [];
  final List<AuthorizationRequest> exchangeRequests = [];
  final List<String> refreshedTokens = [];

  @override
  Future<TokenSet> exchangeCode(
    ServerConnection connection, {
    required String code,
    required AuthorizationRequest request,
  }) {
    exchangedCodes.add(code);
    exchangeRequests.add(request);
    final handler = onExchange;
    if (handler == null) throw StateError('no exchange expected');
    return handler(code);
  }

  @override
  Future<TokenSet> refresh(ServerConnection connection, String refreshToken) {
    refreshedTokens.add(refreshToken);
    final handler = onRefresh;
    if (handler == null) throw StateError('no refresh expected');
    return handler(refreshToken);
  }
}

/// Asks the token source like the auth interceptor does and records which
/// access token each call carried. Both reads of `GET /user` count as
/// [currentUserTokens] and answer with [onCurrentUser]; the one with
/// settings adds [settings].
final class FakeAccountGateway implements AccountGateway {
  Future<User> Function(String accessToken)? onCurrentUser;
  Future<void> Function(String accessToken)? onLogout;
  UserSettings settings = const UserSettings();
  final List<String> currentUserTokens = [];
  final List<String> logoutTokens = [];

  @override
  Future<User> currentUser(
    ServerConnection connection,
    AccessTokenSource tokens,
  ) async {
    final token = await tokens.validAccessToken();
    currentUserTokens.add(token);
    final handler = onCurrentUser;
    if (handler == null) throw StateError('no GET /user expected');
    return await handler(token);
  }

  @override
  Future<UserWithSettings> currentUserWithSettings(
    ServerConnection connection,
    AccessTokenSource tokens,
  ) async => (user: await currentUser(connection, tokens), settings: settings);

  @override
  Future<void> logout(
    ServerConnection connection,
    AccessTokenSource tokens,
  ) async {
    final token = await tokens.validAccessToken();
    logoutTokens.add(token);
    await onLogout?.call(token);
  }
}

typedef WebAuthenticationHandler = Future<Uri?> Function(
  Uri url,
  String callbackUrlScheme,
);

final class FakeWebAuthenticator implements WebAuthenticator {
  new([WebAuthenticationHandler? handler])
    : handler = handler ?? completingSignIn();

  WebAuthenticationHandler handler;
  final List<Uri> urls = [];
  final List<String> schemes = [];

  @override
  Future<Uri?> authenticate(Uri url, {required String callbackUrlScheme}) {
    urls.add(url);
    schemes.add(callbackUrlScheme);
    return handler(url, callbackUrlScheme);
  }
}

/// Behaves like Vikunja's web page: redirects with a code and the state of
/// the request.
WebAuthenticationHandler completingSignIn({String code = 'auth-code'}) =>
    (url, _) async => appOAuthClient.redirectUri.replace(
      queryParameters: {'code': code, 'state': url.queryParameters['state']},
    );

/// Fakes for everything sign-in touches, with the providers to override.
final class AuthFakes {
  /// The notification setup has been shown on this device unless a test
  /// says otherwise, so the signed-in app opens on the shell.
  new({bool notificationsOnboarded = true}) {
    if (notificationsOnboarded) {
      preferences.values[notificationsOnboardedKey] = 'true';
    }
  }

  final secureStore = MemorySecureStore();
  final preferences = MemoryPreferencesStore();
  final webAuthenticator = FakeWebAuthenticator();
  final tokenGateway = FakeTokenGateway();
  final accountGateway = FakeAccountGateway();

  late final tokenStore = TokenStore(secureStore);
  late final registry = AccountRegistry(preferences);
  late final clockOffsets = ServerClockOffsets(preferences);

  List<Override> get overrides => [
    secureStoreProvider.overrideWithValue(secureStore),
    preferencesStoreProvider.overrideWithValue(preferences),
    webAuthenticatorProvider.overrideWithValue(webAuthenticator),
    tokenGatewayProvider.overrideWithValue(tokenGateway),
    accountGatewayProvider.overrideWithValue(accountGateway),
  ];

  /// A server that signs in [user] and answers GET /user for it.
  void serveUser(User user, {required DateTime now}) {
    tokenGateway.onExchange = (_) async =>
        issueTokens(issuedAt: now, userId: user.id, username: user.username);
    accountGateway.onCurrentUser = (_) async => user;
  }

  /// Stores a signed-in account as a previous app run would have left it.
  Future<RegisteredAccount> seedAccount(
    ServerConnection connection, {
    required TokenSet tokens,
    String displayName = 'Alice Example',
    bool needsReauth = false,
    bool activate = true,
  }) async {
    final entry = RegisteredAccount(
      account: Account(
        id: accountIdFor(connection.rootUri, tokens.userId),
        serverRoot: connection.rootUri,
        userId: tokens.userId,
        username: tokens.username,
        displayName: displayName,
        addedAt: DateTime.utc(2026, 10),
        needsReauth: needsReauth,
      ),
      connection: connection,
    );
    // A separate instance, like a previous run of the app.
    await AccountRegistry(preferences).upsert(entry, activate: activate);
    await tokenStore.write(entry.id, tokens);
    return entry;
  }
}
