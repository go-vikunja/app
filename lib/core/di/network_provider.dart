import 'dart:async';
import 'dart:developer' as developer;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/data_source_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/data/data_sources/oauth_data_source.dart';
import 'package:vikunja_app/domain/entities/auth_model.dart';
import 'package:vikunja_app/domain/entities/user.dart';

part 'network_provider.g.dart';

@Riverpod(keepAlive: true)
class AuthData extends _$AuthData {
  @override
  AuthModel? build() => null;

  void set(AuthModel token) {
    state = token;
    ref.invalidate(clientProviderProvider);
  }

  /// Updates only the token without invalidating ClientProvider.
  /// Used by the OAuth refresh flow to update authData while keeping
  /// the current Client instance alive (in-place token update).
  void updateToken(String token) {
    if (state == null) return;
    state = AuthModel(state!.address, token);
  }
}

@Riverpod(keepAlive: true)
class CurrentUser extends _$CurrentUser {
  @override
  User? build() => null;

  void set(User user) => state = user;
}

/// Holds OAuth-specific state: refresh token and access token expiry.
/// Null when the session is a password-based login.
class OAuthTokenState {
  final String refreshToken;
  final DateTime expiresAt;
  OAuthTokenState({required this.refreshToken, required this.expiresAt});
}

@Riverpod(keepAlive: true)
class OAuthTokenManager extends _$OAuthTokenManager {
  Completer<void>? _refreshLock;

  @override
  OAuthTokenState? build() => null;

  void setTokens(OAuthTokenState tokens) => state = tokens;

  void clear() => state = null;

  bool get isOAuth => state != null;

  bool get needsRefresh =>
      state != null &&
      state!.expiresAt.isBefore(
        DateTime.now().add(const Duration(seconds: 30)),
      );

  /// Ensures the access token is valid, refreshing if needed.
  /// Serializes concurrent calls so only one refresh request fires.
  Future<void> ensureValidToken(Client client) async {
    if (!needsRefresh) return;

    // If a refresh is already in progress, wait for it
    if (_refreshLock != null) {
      await _refreshLock!.future;
      return;
    }

    _refreshLock = Completer<void>();
    try {
      await _doRefresh(client);
      _refreshLock!.complete();
    } catch (e) {
      _refreshLock!.completeError(e);
      rethrow;
    } finally {
      _refreshLock = null;
    }
  }

  Future<void> _doRefresh(Client client) async {
    final oauthDataSource = ref.read(oAuthDataSourceProvider);
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final baseUrl = ref.read(authDataProvider)?.address;

    if (baseUrl == null || state == null) return;

    try {
      final tokens = await oauthDataSource.refreshToken(
        baseUrl: baseUrl,
        refreshToken: state!.refreshToken,
      );

      // Update in-memory OAuth state
      state = OAuthTokenState(
        refreshToken: tokens.refreshToken,
        expiresAt: DateTime.now().add(Duration(seconds: tokens.expiresIn)),
      );

      // Update the Client's token in-place (current request uses new token)
      client.token = tokens.accessToken;

      // Update authData without invalidating ClientProvider
      ref.read(authDataProvider.notifier).updateToken(tokens.accessToken);

      // Persist to storage
      await settingsRepo.saveUserToken(tokens.accessToken);
      await settingsRepo.saveRefreshToken(tokens.refreshToken);
      await settingsRepo.saveTokenExpiry(state!.expiresAt);
    } on OAuthException catch (e) {
      developer.log('OAuth refresh failed: $e');
      // Clear OAuth state — session is gone
      state = null;
      await settingsRepo.saveRefreshToken(null);
      await settingsRepo.saveTokenExpiry(null);
      await settingsRepo.saveAuthType(null);
      rethrow;
    }
  }
}

@Riverpod(keepAlive: true)
class ClientProvider extends _$ClientProvider {
  @override
  Client build() {
    final authData = ref.read(authDataProvider);
    final client = Client(
      base: authData?.address ?? '',
      token: authData?.token,
    );

    // If this is an OAuth session, wire up proactive token refresh
    final oauthManager = ref.read(oAuthTokenManagerProvider.notifier);
    if (oauthManager.isOAuth) {
      client.onBeforeRequest = (c) => oauthManager.ensureValidToken(c);
    }

    return client;
  }
}
