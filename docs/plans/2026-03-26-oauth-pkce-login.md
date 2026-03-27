# OAuth PKCE Login Refactor Implementation Plan

**Goal:** Replace all existing login/register methods with a single OAuth 2.0 PKCE flow: ask for Vikunja URL, validate via `/api/v1/info`, launch browser-based OAuth, capture callback, exchange code for tokens, and use OAuth refresh tokens instead of cookie-based refresh.

**Architecture:** The login page becomes a simple URL input form. After URL validation, the app generates PKCE credentials, opens the system browser to the Vikunja frontend's `/oauth/authorize` route, and listens for the `vikunja-flutter://callback` deep link. The authorization code is exchanged for tokens via `POST /api/v1/oauth/token` (JSON body). Token refresh uses the same endpoint with `grant_type=refresh_token`. The old cookie-based refresh, username/password login, webview login, and registration are all removed.

**Tech Stack:** Flutter, `url_launcher` (already in pubspec), `app_links` (deep link handling), `crypto` (dart:convert + dart:math for PKCE S256), `http` (already in pubspec), `flutter_secure_storage` (already in pubspec), Riverpod for state management.

---

### Task 1: Add `app_links` dependency and configure platform deep links

**Files:**
- Modify: `pubspec.yaml` (add `app_links` dependency)
- Modify: `android/app/src/main/AndroidManifest.xml` (add intent-filter for `vikunja-flutter://` scheme)
- Modify: `ios/Runner/Info.plist` (add `CFBundleURLTypes` for `vikunja-flutter` scheme)

**Step 1: Add app_links to pubspec.yaml**

In `pubspec.yaml`, under `dependencies:`, add:

```yaml
  app_links: ^6.4.0
```

Remove the `webview_flutter` dependency (no longer needed):

```yaml
  # REMOVE this line:
  webview_flutter: ^4.7.0
```

**Step 2: Add Android deep link intent-filter**

In `android/app/src/main/AndroidManifest.xml`, inside the `<activity android:name=".MainActivity" ...>` tag, add a new intent-filter after the existing ones:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="vikunja-flutter" android:host="callback" />
</intent-filter>
```

**Step 3: Add iOS URL scheme**

In `ios/Runner/Info.plist`, add inside the top-level `<dict>`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>vikunja-flutter</string>
        </array>
    </dict>
</array>
```

**Step 4: Run `flutter pub get`**

```bash
cd /home/clawd/projects/vikunja/app && flutter pub get
```

Expected: resolves successfully.

**Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "feat: add app_links dependency and configure deep link scheme for OAuth callback"
```

---

### Task 2: Add OAuth refresh token storage to SettingsDatasource

The old flow stored a `refresh-cookie`. The new OAuth flow uses a `refresh_token` string from the token response. We repurpose the existing `refresh-cookie` storage key as `refresh-token` for clarity, and add a helper to clear all auth data at once.

**Files:**
- Modify: `lib/data/data_sources/settings_data_source.dart`
- Modify: `lib/domain/repositories/settings_repository.dart`
- Modify: `lib/data/repositories/settings_repository_impl.dart`

**Step 1: Update SettingsDatasource**

In `lib/data/data_sources/settings_data_source.dart`:

Rename `getRefreshCookie` -> `getRefreshToken` and `saveRefreshCookie` -> `saveRefreshToken`. Change the storage key from `"refresh-cookie"` to `"refresh-token"`:

```dart
Future<String?> getRefreshToken() {
  return _storage.read(key: "refresh-token");
}

Future<void> saveRefreshToken(String? token) {
  return _storage.write(key: "refresh-token", value: token);
}
```

Add a method to clear all auth data:

```dart
Future<void> clearAuthData() async {
  await saveUserToken(null);
  await saveRefreshToken(null);
  await saveServer(null);
}
```

**Step 2: Update SettingsRepository interface**

In `lib/domain/repositories/settings_repository.dart`, rename:
- `saveRefreshCookie` -> `saveRefreshToken`
- `getRefreshCookie` -> `getRefreshToken`

Add:
```dart
Future<void> clearAuthData();
```

**Step 3: Update SettingsRepositoryImpl**

In `lib/data/repositories/settings_repository_impl.dart`, update the method names to match the new interface, delegating to the datasource's renamed methods.

**Step 4: Update all callers**

Search for all references to `saveRefreshCookie` and `getRefreshCookie` across the codebase and rename them. Key files:
- `lib/presentation/pages/login/login_page.dart` (will be rewritten in Task 4)
- `lib/init_page.dart` (will be rewritten in Task 5)
- `lib/core/network/client.dart` (will be updated in Task 3)
- `lib/core/background_work.dart`

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor: rename refresh cookie storage to refresh token for OAuth flow"
```

---

### Task 3: Rewrite token refresh in Client to use OAuth endpoint

The old `tryRefreshToken()` in `Client` sends a cookie-based POST to `/user/token/refresh`. The new OAuth flow uses `POST /oauth/token` with `grant_type=refresh_token` in a JSON body. The response contains `access_token` and `refresh_token` (rotated).

**Files:**
- Modify: `lib/core/network/client.dart`

**Step 1: Rewrite `tryRefreshToken()`**

Replace the existing `tryRefreshToken()` method:

```dart
Future<bool> tryRefreshToken() async {
  try {
    return await TokenLock.synchronized(() async {
      final refreshClient = _createIOClient();
      try {
        var refreshToken = await settingsDatasource.getRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          return false;
        }

        var response = await refreshClient.post(
          '$_baseUrl/api/v1/oauth/token'.toUri()!,
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'Vikunja Mobile App',
          },
          body: _encoder.convert({
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
          }),
        );

        if (response.statusCode >= 200 && response.statusCode < 400) {
          var body = _decoder.convert(utf8.decode(response.bodyBytes));
          var newAccessToken = body['access_token'] as String?;
          var newRefreshToken = body['refresh_token'] as String?;

          if (newAccessToken != null && newAccessToken.isNotEmpty) {
            await settingsDatasource.saveUserToken(newAccessToken);
            if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
              await settingsDatasource.saveRefreshToken(newRefreshToken);
            }
            return true;
          }
        }
      } finally {
        refreshClient.close();
      }

      return false;
    });
  } catch (e) {
    developer.log("Error refreshing token: $e");
    return false;
  }
}
```

**Step 2: Add `_baseUrl` field**

The Client currently stores `_base` which has `/api/v1` appended. We need the raw base URL for the OAuth endpoint. Add a `_baseUrl` field:

```dart
String _baseUrl = '';

// In constructor, before the _base assignment:
_baseUrl = base;
// Keep existing: _base = base.endsWith('/api/v1') ? base : '$base/api/v1';
```

**Step 3: Remove `getHeaders` refresh parameter and cookie logic**

In `getHeaders()`, remove the `refresh` parameter and the cookie branch. The method should only return the Bearer token header:

```dart
Future<Map<String, String>> getHeaders() async {
  var headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'Vikunja Mobile App',
  };

  var token = await settingsDatasource.getUserToken();
  headers['Authorization'] = token != '' ? 'Bearer $token' : '';

  return headers;
}
```

Remove `postWithCookies` method entirely (no longer needed).

**Step 4: Remove `extractRefreshCookie` from `lib/core/utils/network.dart`**

Delete the `extractRefreshCookie` function.

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor: rewrite token refresh to use OAuth token endpoint"
```

---

### Task 4: Create OAuth PKCE service and rewrite login page

This is the core task. Create an OAuth service that handles PKCE generation, browser launch, deep link capture, and token exchange. Then rewrite the login page to: (1) ask for URL, (2) validate via `/api/v1/info`, (3) launch OAuth flow.

**Files:**
- Create: `lib/core/oauth/oauth_service.dart`
- Modify: `lib/presentation/pages/login/login_page.dart` (full rewrite)
- Delete: `lib/presentation/pages/login/register_page.dart`
- Delete: `lib/presentation/pages/login/login_webview.dart`

**Step 1: Create OAuth service**

Create `lib/core/oauth/oauth_service.dart`:

```dart
import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class OAuthTokenResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  OAuthTokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory OAuthTokenResponse.fromJson(Map<String, dynamic> json) {
    return OAuthTokenResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int,
    );
  }
}

class OAuthService {
  static const String _clientId = 'vikunja-flutter';
  static const String _redirectUri = 'vikunja-flutter://callback';
  static const String _charset =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  String _codeVerifier = '';
  String _state = '';

  /// Generates a cryptographically random code verifier for PKCE (43-128 chars).
  String _generateCodeVerifier() {
    final random = Random.secure();
    return List.generate(
      128,
      (_) => _charset[random.nextInt(_charset.length)],
    ).join();
  }

  /// Generates the S256 code challenge from the code verifier.
  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Generates a random state parameter for CSRF protection.
  String _generateState() {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => _charset[random.nextInt(_charset.length)],
    ).join();
  }

  /// Launches the OAuth authorization flow in the system browser.
  /// Returns a Future that completes with the authorization code
  /// when the app receives the callback deep link.
  Future<String> authorize(String serverUrl) async {
    _codeVerifier = _generateCodeVerifier();
    _state = _generateState();
    final codeChallenge = _generateCodeChallenge(_codeVerifier);

    final authorizeUrl = Uri.parse('$serverUrl/oauth/authorize').replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': _clientId,
        'redirect_uri': _redirectUri,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'state': _state,
      },
    );

    final launched = await launchUrl(
      authorizeUrl,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      throw Exception('Could not launch browser for OAuth authorization');
    }

    // Listen for the callback deep link
    final appLinks = AppLinks();
    final callbackUri = await appLinks.uriLinkStream.firstWhere(
      (uri) => uri.scheme == 'vikunja-flutter' && uri.host == 'callback',
    );

    final returnedState = callbackUri.queryParameters['state'];
    if (returnedState != _state) {
      throw Exception('OAuth state mismatch - possible CSRF attack');
    }

    final code = callbackUri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw Exception('No authorization code received from OAuth callback');
    }

    return code;
  }

  /// Exchanges the authorization code for access and refresh tokens.
  Future<OAuthTokenResponse> exchangeCode(
    String serverUrl,
    String code,
  ) async {
    final response = await http.post(
      Uri.parse('$serverUrl/api/v1/oauth/token'),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Vikunja Mobile App',
      },
      body: jsonEncode({
        'grant_type': 'authorization_code',
        'code': code,
        'client_id': _clientId,
        'redirect_uri': _redirectUri,
        'code_verifier': _codeVerifier,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(
        'Token exchange failed: ${error['message'] ?? response.body}',
      );
    }

    return OAuthTokenResponse.fromJson(jsonDecode(response.body));
  }
}
```

**IMPORTANT:** This requires adding the `crypto` package to pubspec.yaml:

```yaml
  crypto: ^3.0.6
```

**Step 2: Rewrite login page**

Replace `lib/presentation/pages/login/login_page.dart` entirely. The new page:
1. Shows logo + server URL input (with autocomplete from past servers) + "Connect" button + ignore certs checkbox + sentry dialog on first launch
2. On "Connect": validates URL via `GET /api/v1/info`, then launches OAuth flow
3. On OAuth callback: exchanges code, stores tokens, navigates to home

```dart
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/oauth/oauth_service.dart';
import 'package:vikunja_app/core/utils/constants.dart';
import 'package:vikunja_app/core/utils/network.dart';
import 'package:vikunja_app/core/utils/validator.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/domain/entities/auth_model.dart';
import 'package:vikunja_app/domain/entities/server.dart';
import 'package:vikunja_app/domain/entities/version.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/main.dart';
import 'package:vikunja_app/presentation/widgets/button.dart';
import 'package:vikunja_app/presentation/widgets/sentry_dialog.dart';
import 'package:vikunja_app/presentation/widgets/version_mismatch_dialog.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  List<String> pastServers = [];

  final _serverController = TextEditingController();
  final _oauthService = OAuthService();

  @override
  void initState() {
    super.initState();

    var settingsDatasource = SettingsDatasource(FlutterSecureStorage());
    settingsDatasource.clearAuthData();

    Future.delayed(Duration.zero, () async {
      var pastSevers = await ref
          .read(settingsRepositoryProvider)
          .getPastServers();
      setState(() => pastServers = pastSevers);

      var sentryDialogShown = await ref
          .read(settingsRepositoryProvider)
          .getSentryDialogShown();

      if (!sentryDialogShown) {
        ref.read(settingsRepositoryProvider).setSentryDialogShown(true);
        return _showSentryDialog();
      }
    });
  }

  Future<void> _showSentryDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return SentryDialog(
          onAccepts: () {
            ref.read(settingsRepositoryProvider).setSentryEnabled(true);
          },
          onRefuse: () {
            ref.read(settingsRepositoryProvider).setSentryEnabled(false);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext ctx) {
    Client client = ref.read(clientProviderProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          autovalidateMode: AutovalidateMode.always,
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _buildLogo(),
              _buildServerInput(),
              Padding(
                padding: vStandardVerticalPadding,
                child: SizedBox(
                  width: double.infinity,
                  child: FancyButton(
                    onPressed: !_loading
                        ? () {
                            if (_formKey.currentState!.validate()) {
                              _formKey.currentState?.save();
                              _connectAndLogin(context);
                            }
                          }
                        : null,
                    child: _loading
                        ? CircularProgressIndicator()
                        : Text(AppLocalizations.of(context).login),
                  ),
                ),
              ),
              CheckboxListTile(
                title: Text(AppLocalizations.of(context).ignoreCertificates),
                value: client.ignoreCertificates,
                onChanged: (value) {
                  ref
                      .read(settingsRepositoryProvider)
                      .setIgnoreCertificates(value ?? false);
                  setState(() {
                    client.setIgnoreCerts(value ?? false);
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Padding _buildServerInput() {
    return Padding(
      padding: vStandardVerticalPadding,
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          List<String> matches = <String>[];
          matches.addAll(pastServers);
          matches.retainWhere((s) {
            return s.toLowerCase().contains(
              textEditingValue.text.toLowerCase(),
            );
          });
          return matches;
        },
        focusNode: FocusNode(),
        textEditingController: _serverController,
        onSelected: (String selection) {
          _serverController.text = selection;
          setState(() => _serverController.text = selection);
        },
        fieldViewBuilder:
            (
              BuildContext context,
              TextEditingController textEditingController,
              FocusNode focusNode,
              VoidCallback onFieldSubmitted,
            ) =>
                _buildServerTextView(textEditingController, focusNode, context),
        optionsViewBuilder:
            (
              BuildContext context,
              AutocompleteOnSelected<String> onSelected,
              Iterable<String> options,
            ) => _buildServerOptions(options, onSelected),
      ),
    );
  }

  TextFormField _buildServerTextView(
    TextEditingController textEditingController,
    FocusNode focusNode,
    BuildContext context,
  ) {
    return TextFormField(
      controller: textEditingController,
      focusNode: focusNode,
      enabled: !_loading,
      validator: (address) {
        return isURLValid(address)
            ? null
            : AppLocalizations.of(context).invalidUrl;
      },
      decoration: InputDecoration(
        border: OutlineInputBorder(),
        labelText: AppLocalizations.of(context).serverAddress,
      ),
    );
  }

  ListView _buildServerOptions(
    Iterable<String> options,
    AutocompleteOnSelected<String> onSelected,
  ) {
    return ListView(
      padding: EdgeInsets.zero,
      children: options.map((item) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: InkWell(
              onTap: () {
                onSelected(item);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        pastServers.remove(item);
                        ref
                            .read(settingsRepositoryProvider)
                            .setPastServers(pastServers);
                      });
                    },
                    icon: Icon(Icons.clear),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Padding _buildLogo() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 30),
      child: Image(
        image: Theme.of(context).brightness == Brightness.dark
            ? AssetImage('assets/vikunja_logo_full_white.png')
            : AssetImage('assets/vikunja_logo_full.png'),
        height: 85.0,
        semanticLabel: AppLocalizations.of(context).vikunjaLogoAlt,
      ),
    );
  }

  Future<void> _connectAndLogin(BuildContext context) async {
    String server = normalizeServerURL(_serverController.text);
    if (server.isEmpty) return;

    setState(() => _loading = true);

    try {
      // Step 1: Set up the client so we can call the API
      ref.read(authDataProvider.notifier).set(AuthModel(server));
      ref.read(settingsRepositoryProvider).saveServer(server);

      // Step 2: Validate via /api/v1/info
      Response<Server> info = await ref
          .read(serverRepositoryProvider)
          .getInfo();

      if (!info.isSuccessful) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).cannotReachServer),
            ),
          );
        }
        return;
      }

      Sentry.configureScope(
        (scope) => scope.setTag(
          'server.version',
          info.toSuccess().body.version ?? "-",
        ),
      );

      Version? serverVersion = Version.fromServerString(
        info.toSuccess().body.version ?? "-",
      );

      // Save to past servers
      if (!pastServers.contains(server)) {
        pastServers.add(server);
        ref.read(settingsRepositoryProvider).setPastServers(pastServers);
      }

      // Step 3: Launch OAuth PKCE flow
      String code = await _oauthService.authorize(server);

      // Step 4: Exchange code for tokens
      OAuthTokenResponse tokens = await _oauthService.exchangeCode(
        server,
        code,
      );

      // Step 5: Store tokens and navigate
      await ref
          .read(settingsRepositoryProvider)
          .saveUserToken(tokens.accessToken);
      await ref
          .read(settingsRepositoryProvider)
          .saveRefreshToken(tokens.refreshToken);

      // Re-set auth data so the client picks up the new token
      ref.read(authDataProvider.notifier).set(AuthModel(server));

      // Step 6: Fetch current user
      var currentUser = await ref.read(userRepositoryProvider).getCurrentUser();
      if (currentUser.isSuccessful) {
        ref
            .read(currentUserProvider.notifier)
            .set(currentUser.toSuccess().body);

        if (serverVersion != null &&
            !serverVersion.isCompatibleWith(minimumServerVersion) &&
            context.mounted) {
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return VersionMismatchDialog(serverVersion: serverVersion);
            },
          );
        }

        if (context.mounted) {
          Navigator.pushReplacementNamed(context, "/home");
        }
      } else {
        if (context.mounted) {
          _showGenericError(context);
        }
      }
    } catch (e) {
      log("Login failed: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showGenericError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).somethingWentWrong)),
    );
  }
}
```

**Step 3: Delete old files**

```bash
rm lib/presentation/pages/login/register_page.dart
rm lib/presentation/pages/login/login_webview.dart
```

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: implement OAuth PKCE login flow, remove username/password and webview login"
```

---

### Task 5: Update InitPage to use OAuth refresh tokens

The `InitPage` currently checks for a refresh cookie. It needs to check for a refresh token instead and use the OAuth refresh mechanism.

**Files:**
- Modify: `lib/init_page.dart`

**Step 1: Update `checkLoginToken`**

Change from checking `refreshCookie` to checking `refreshToken`:

```dart
Future<Object?> checkLoginToken(WidgetRef ref) async {
  var server = await ref.read(settingsRepositoryProvider).getServer();
  var refreshToken = await ref
      .read(settingsRepositoryProvider)
      .getRefreshToken();

  if (server != null && refreshToken != null) {
    return checkServer(ref, server);
  }

  globalNavigatorKey.currentState?.pushReplacementNamed("/login");
  return null;
}
```

**Step 2: Update `onLoginError`**

Change `saveRefreshCookie` to `saveRefreshToken`:

```dart
Future<Object?> onLoginError(
  WidgetRef ref,
  ErrorResponse<User> userResponse,
) async {
  if (userResponse.statusCode == 401) {
    ref.read(settingsRepositoryProvider).saveUserToken(null);
    ref.read(settingsRepositoryProvider).saveRefreshToken(null);
    // ... rest unchanged
  }
  // ...
}
```

**Step 3: Commit**

```bash
git add lib/init_page.dart
git commit -m "refactor: update InitPage to use OAuth refresh tokens"
```

---

### Task 6: Update background_work.dart to use refresh tokens

**Files:**
- Modify: `lib/core/background_work.dart`

**Step 1: Update `updateTasks()`**

Replace `refreshCookie` with `refreshToken`:

```dart
Future<bool> updateTasks() async {
  var datasource = SettingsDatasource(FlutterSecureStorage());
  var base = await datasource.getServer();
  var refreshToken = await datasource.getRefreshToken();

  if (refreshToken == null || base == null) {
    return Future.value(true);
  }

  // ... rest unchanged
}
```

**Step 2: Commit**

```bash
git add lib/core/background_work.dart
git commit -m "refactor: update background work to check OAuth refresh token"
```

---

### Task 7: Remove unused login/register code from UserRepository and data sources

Since login and register are no longer done via the API client's `POST /login` and `POST /register` endpoints (OAuth handles it), we can remove these methods.

**Files:**
- Modify: `lib/domain/repositories/user_repository.dart` (remove `login`, `register`)
- Modify: `lib/data/repositories/user_repository_impl.dart` (remove `login`, `register`)
- Modify: `lib/data/data_sources/user_data_source.dart` (remove `login`, `register`)
- Modify: `lib/domain/entities/user.dart` (remove `UserToken`, `BaseTokenPair` classes)

**Step 1: Remove `login` and `register` from UserRepository interface**

```dart
abstract class UserRepository {
  Future<Response<User>> getCurrentUser();
  Future<Response<UserSettings>> setCurrentUserSettings(UserSettings userSettings);
}
```

**Step 2: Remove from UserRepositoryImpl**

Remove the `login` and `register` method overrides.

**Step 3: Remove from UserDataSource**

Remove the `login` and `register` methods.

**Step 4: Remove `UserToken` and `BaseTokenPair` from user.dart**

These classes are no longer needed since tokens come from the OAuth service.

**Step 5: Clean up imports**

Search the codebase for any remaining imports of `UserToken`, `BaseTokenPair`, `login_webview.dart`, or `register_page.dart` and remove them.

**Step 6: Commit**

```bash
git add -A
git commit -m "refactor: remove unused login/register methods and UserToken class"
```

---

### Task 8: Clean up unused localization keys and remove dead code

**Files:**
- Various localization files (optional, can be deferred)
- Any remaining references to removed code

**Step 1: Search for dead references**

```bash
grep -rn "register_page\|login_webview\|UserToken\|BaseTokenPair\|refreshCookie\|refresh_cookie\|loginWithFrontend\|rememberMe" lib/
```

Fix any remaining references found.

**Step 2: Commit**

```bash
git add -A
git commit -m "chore: clean up dead references from old login flow"
```

---

### Task 9: Verify the build compiles

**Step 1: Run flutter analyze**

```bash
cd /home/clawd/projects/vikunja/app && flutter analyze
```

Expected: No errors (warnings are OK).

**Step 2: Run build_runner for generated Riverpod code**

If any providers were changed:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

**Step 3: Commit any generated file changes**

```bash
git add -A
git commit -m "chore: regenerate riverpod providers"
```

---

## Key Implementation Notes

1. **PKCE S256:** The `crypto` package provides `sha256`. The code verifier is a random 128-char string from the unreserved character set. The challenge is `base64url(sha256(verifier))` with padding stripped.

2. **Deep link capture:** `app_links` listens for the `vikunja-flutter://callback?code=...&state=...` redirect. The app must be configured with `singleTop` launch mode (already set in AndroidManifest).

3. **Token refresh rotation:** Each refresh rotates the refresh token. The old one is immediately invalidated. Always save both `access_token` and `refresh_token` from the response.

4. **No form encoding:** The Vikunja OAuth API only accepts JSON. All POST bodies must use `Content-Type: application/json`.

5. **Existing mechanisms preserved:** Past server autocomplete, ignore certificates, Sentry dialog, version mismatch warning - all kept in the new login page.
