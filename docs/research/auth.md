# Vikunja authentication and sessions for a mobile client (API v1 and v2)

Source: shallow clone of `main` (latest release v2.7.0, 2026-10-02). Every path below is relative to the repo root.
Labels used: **[V]** means I read it in the source. **[I]** means I inferred it (from library behaviour or general knowledge) and did not verify it in this repo.

---

## 0. TL;DR: decisions for the Flutter app

1. **Use Vikunja's own OAuth 2.0 + PKCE server as the primary login.** It exists on servers ≥ 2.3.0 and is what the official Electron desktop app and the `veans` CLI use. Open `<frontend_url>oauth/authorize?...&redirect_uri=vikunja-<app>://callback` in the system browser (`flutter_web_auth_2` → ASWebAuthenticationSession or Custom Tabs). The web frontend then handles every login method (local, LDAP, any OIDC provider, TOTP), and the app receives a Vikunja code. Exchange it at `POST /api/v2/oauth/token` (or `/api/v1/oauth/token`). Both tokens come back **in the JSON body**, so no cookies are involved. [V] `pkg/modules/auth/oauth2server/*`, `frontend/src/views/user/OAuthAuthorize.vue`, `desktop/oauth.js`, `veans/internal/auth/oauth.go`
2. **Access tokens are short-lived JWTs** (`service.jwtttlshort`, default 600 s). **Refresh tokens are opaque.** They rotate on every use and are stored server-side in the `sessions` table. A session survives as long as it is refreshed within `service.jwtttl` (72 h, sliding) or, for "long" sessions, within `service.jwtttllong` (30 d). OAuth-code sessions are always the short kind. [V] `pkg/modules/auth/auth.go`, `pkg/models/sessions.go`, `pkg/modules/auth/oauth2server/token.go`
3. **On `401` with body `code == 11`, refresh once and retry once.** Run the refresh single-flight, under a cross-isolate lock, and re-read the stored token after acquiring the lock. Refresh fails with 401 and code 16002/16003/16004/16005. Codes 16002 and 16003 mean the session is gone. [V] `pkg/routes/api_tokens.go`, `frontend/src/client/http.ts`, `frontend/src/helpers/auth.ts`
4. **Fallbacks:**
   - Native username/password form via `POST /api/v{1,2}/login` with `long_token:true`. The refresh token then arrives only as a `Set-Cookie`. The app parses it once and can afterwards refresh via `/oauth/token` with `grant_type=refresh_token` (≥ 2.3.0), because both flows share the same session table.
   - Pasted API token (`tk_…`), as an advanced option with limited scope.
   - Link-share hash login.
5. **Native OIDC without the Vikunja frontend is not portable.** The server exchanges the IdP code as a confidential client using a `redirect_url` that the caller supplies, with no PKCE. A custom-scheme redirect works only if the admin registers it at the IdP. Intercepting the https frontend redirect is impossible in ASWebAuthenticationSession or Custom Tabs for arbitrary self-hosted domains. [V for the server side; I for the platform constraints]

---

## 1. Version timeline and capability detection

| Feature | First release | Evidence |
|---|---|---|
| API tokens (`tk_…`, scoped) | 0.22.0 | `CHANGELOG.md` §0.22.0 "*(api tokens)* Add api token struct and migration" |
| `POST /user/token` renews **user** JWTs (pre-session era) | 0.10 → removed in 2.0.0 | `CHANGELOG.md` §0.10 "Add user token renew (#113)". Current `pkg/routes/api/v1/login.go:RenewToken` rejects user tokens with 400 |
| Sessions table, short JWT, rotating refresh token in HttpOnly cookie, `jwtttlshort` | 2.0.0 (2026-02-25) | `CHANGELOG.md` §2.0.0 "Add session-based auth with refresh token rotation", "Add jwtttlshort config key" |
| `StatusAccountLocked` after TOTP lockout; enabling TOTP revokes all sessions | 2.2.0 | `CHANGELOG.md` §2.2.0 |
| Vikunja OAuth 2.0 server (authorize + token, PKCE), frontend `/oauth/authorize`; WebSocket `/api/v1/ws`; TOTP for OIDC logins | 2.3.0 (2026-04-09) | `CHANGELOG.md` §2.3.0 "Add OAuth 2.0 authorize endpoint", "Add OAuth 2.0 token endpoint", "*(websocket)* Add HTTP upgrade handler and /api/v1/ws route", "Add TOTPPasscode to OIDC Callback payload" |
| `/api/v2` (login, logout, refresh, OIDC callback, sessions, tokens, OAuth, link share, …) | 2.4.0 (2026-07-19) | `CHANGELOG.md` §2.4.0 "*(api/v2)* Add login and logout on /api/v2", etc. |
| Separate rate-limit budget for refresh (`ratelimit.tokenrefreshlimit`) | 2.6.0 | `CHANGELOG.md` §2.6.0 "*(ratelimit)* Give session renewal its own budget" |
| WebSocket re-auth on open socket; sockets closed on session revocation | 2.7.0 | `CHANGELOG.md` §2.7.0 |

**Detection [V for endpoints; I for the strategy]:**
- `GET /api/v1/info` (public, all versions) returns `version` (`version.Version`, injected from git via `magefile.go` ldflags, e.g. `v2.7.0`; dev builds report `dev`). `GET /api/v2/info` returns 200 only on ≥ 2.4.0. [V] `pkg/routes/api/shared/info.go`, `pkg/routes/api/v2/info.go`, `pkg/version/*.go`
- To probe the OAuth server, `POST /api/v1/oauth/token` with `{"grant_type":"x"}` returns 400 with code 17007 on ≥ 2.3.0 and 404 on older servers. [I]
- Prefer feature probes over version parsing, because dev builds report `dev`.

The frontend discovers the API like this: it strips `/api/vN`, tries the given URL, then the same host on port 3456, and probes `/info`. [V] `frontend/src/helpers/checkAndSetApiUrl.ts`, `frontend/src/helpers/apiUrl.ts`. The current frontend talks only to `/api/v2` (`getApiBaseUrl()` returns `${root}/api/v2`).

---

## 2. Transport basics

- **Header:** `Authorization: Bearer <jwt-or-api-token>` for both API versions. In the v2 OpenAPI spec the schemes are `JWTKeyAuth` (bearer JWT) and `APITokenAuth` (bearer). In v1 swagger it is an `apiKey` in the `Authorization` header. [V] `pkg/routes/api/v2/huma.go:95-121`, `pkg/swagger/swagger.yaml:7912`
- **How the token type is chosen:** if any `Authorization` value starts with `Bearer tk_`, the request is treated as an API token. Everything else goes through the echo-jwt middleware (HS256, key = `service.secret`). [V] `pkg/models/api_tokens.go:APITokenAuthorization`, `pkg/routes/api_tokens.go:SetupTokenMiddleware`
- **Public (no-JWT) paths:** listed explicitly in `unauthenticatedAPIPaths` [V] `pkg/routes/routes.go:~319-367`. They include `/api/v{1,2}/login`, `/register`, `/user/password/token`, `/user/password/reset`, `/user/confirm`, `/user/token/refresh`, `/auth/openid/:provider/callback`, `/shares/:share/auth`, `/oauth/token`, `/info`, `/api/v2/ws`, and `/api/v2/health`. Note that `/api/v1/ws` is registered in the no-auth group `n`.
- **Error bodies:**
  - v1, and anything rejected by Echo before Huma (invalid JWT, rate limit): `{"code": <int>, "message": "<text>"}`. Plain echo errors produce `{"message": "..."}`. [V] `pkg/web/web.go:HTTPError`, `pkg/routes/error_handler.go`
  - v2 domain errors: `application/problem+json` with `{"status", "title", "detail", "errors"?, "code"?, "i18n_params"?}`. The numeric `code` is the same as in v1. [V] `pkg/routes/api/v2/errors.go:vikunjaErrorModel`, `translateDomainError`
  - v2 validation failures are **422** (v1 uses 412). [V] `pkg/routes/api/v2/errors.go`
  - The frontend normalizes v1-shaped bodies on v2 by stamping `status` and `detail` onto them. [V] `frontend/src/client/problem.ts`
- **v2 POST default status is 201** unless an operation sets `DefaultStatus`. Login, refresh, OAuth token and logout explicitly use 200. [V] `pkg/routes/api/v2/huma.go:150`
- **`Cache-Control: no-store`** is set on every v1 and v2 response. [V] `pkg/routes/routes.go:noStoreCacheControl`
- **CORS does not matter for a native app.** CORS is enabled by default (`cors.enable=true`, which also requires `service.publicurl`) and only uses `AllowCredentials:true` and `ExposeHeaders: Retry-After`. [V] `pkg/routes/routes.go:RegisterRoutes`, `pkg/config/config.go:795`. Native HTTP clients send no `Origin` header, so the CORS middleware is inert for them. [I]

---

## 3. JWT structure and lifetimes

All JWTs are HS256-signed with `service.secret`. If the secret is unset, a random one is generated at every startup, which invalidates all JWTs on restart. Refresh tokens and API tokens are stored in the DB and survive restarts. [V] `config-raw.json` `service.secret` comment, `pkg/config/config.go:565-574`

**User access token** [V] `pkg/modules/auth/auth.go:NewUserJWTAuthtoken`:
```json
{ "type": 1, "id": <userId>, "username": "<name>", "is_admin": <bool>,
  "iat": <unix>, "exp": <iat + service.jwtttlshort>, "sid": "<session uuid>", "jti": "<uuid>" }
```
- The frontend derives its clock offset from `iat`, so `exp` is judged by server time. [V] comment in the same function and `frontend/src/helpers/serverClock`
- The HTTP middleware does **not** check that `sid` still exists. A revoked session's access token stays valid for HTTP until `exp`, at most 10 min by default. `user.GetUserFromClaims` builds the user from the claims alone. [V] `pkg/routes/api_tokens.go` (echojwt only), `pkg/user/user.go:GetUserFromClaims`. Only the WebSocket checks the session. [V] `pkg/websocket/connection.go:handleAuth`

**Link-share token** [V] `pkg/modules/auth/auth.go:NewLinkShareJWTAuthtoken`:
```json
{ "type": 2, "id": <shareId>, "hash": "<share hash>", "project_id": <id>, "permission": <0|1|2>,
  "sharedByID": <userId>, "iat": <unix>, "exp": <iat + service.jwtttl> }
```
- The server re-reads the share on every request and rejects the token if the share was deleted (400, code 13003). [V] `pkg/models/link_sharing.go:GetLinkShareFromClaims`

**Config** [V] `pkg/config/config.go:376-378`, `config-raw.json`:

| key | default | meaning (current code) |
|---|---|---|
| `service.jwtttlshort` | 600 s | Access-token (user JWT) lifetime; also the OAuth `expires_in` |
| `service.jwtttl` | 259200 s (72 h) | Max **inactivity** of a normal session (refresh-token window, sliding on `last_active`); link-share JWT lifetime; refresh-cookie Max-Age |
| `service.jwtttllong` | 2592000 s (30 d) | Same for "long" (`long_token:true`) sessions |

---

## 4. Sessions and refresh tokens

### 4.1 Server model [V] `pkg/models/sessions.go`
- `Session{ id (uuid = JWT sid), user_id, token_hash (sha256 hex of refresh token), device_info (User-Agent at login), ip_address, is_long_session, oidc_id_token, oidc_provider_key, last_active, created }`.
- The refresh token is 128 random bytes, hex-encoded (256 chars). It is returned once and only its hash is stored (`generateHashedToken`).
- **Rotation.** `RotateRefreshToken` runs `UPDATE … WHERE id=? AND token_hash=<old>`. If a concurrent refresh with the same token loses the race, it gets `ErrSessionNotFound`, which the caller maps to **16004 `ErrRefreshTokenAlreadyUsed`**.
- **Expiry.** `RefreshSession` checks `now - last_active > (is_long ? jwtttllong : jwtttl)`. If the session is too old it deletes it and returns **16003 `ErrSessionExpired`**. Otherwise it updates `last_active`, rotates the token, reloads the user and mints a new JWT. A disabled or locked user causes the session to be deleted and returns 412 (1020/1040). [V] `pkg/modules/auth/auth.go:RefreshSession`
- **No reuse detection.** An old, already-rotated token just fails lookup with **16002 `ErrInvalidRefreshToken`**. The session is **not** revoked. [V] `GetSessionByRefreshToken` and `RefreshSession`
- **Mobile consequence [I]:** if the server commits a rotation and the response is lost (flaky network, app suspended), the client still holds a dead token. Its next attempt returns 16002 and the session is unrecoverable, so the user must re-login.
- An hourly cron deletes stale sessions using the same cut-offs. [V] `RegisterSessionCleanupCron`
- `is_long_session` is preserved across rotations, because only `token_hash` is updated. [V]

### 4.2 Where the refresh token lives

| Login path | Refresh token delivery |
|---|---|
| `POST /api/v{1,2}/login`, `POST /api/v{1,2}/auth/openid/{p}/callback` | **Only** as `Set-Cookie: vikunja_refresh_token=<hex>; Path=<publicurl-path>/api/v1/user/token/refresh; Max-Age=<jwtttl or jwtttllong>; HttpOnly; Secure (if publicurl is https); SameSite=Lax`. A **second** identical cookie is set with `Path=…/api/v2/user/token/refresh`. The response body only contains `{"token": "<jwt>"}`. [V] `pkg/modules/auth/auth.go:SetRefreshTokenCookie`, `getRefreshTokenCookiePaths`, `WriteUserAuthCookies`; `pkg/routes/api/v2/auth_login.go:authTokenBody` |
| OAuth `POST /api/v{1,2}/oauth/token` | JSON body `{"access_token","token_type":"bearer","expires_in","refresh_token"}`. No cookie. [V] `pkg/modules/auth/oauth2server/token.go` |

### 4.3 Refresh endpoints

| | v1 | v2 |
|---|---|---|
| Cookie refresh | `POST /api/v1/user/token/refresh` | `POST /api/v2/user/token/refresh` |
| Body / auth | none; reads cookie `vikunja_refresh_token` | same |
| Success | 200 `{"token":"<jwt>"}` plus a new rotated `Set-Cookie` (×2) and `Cache-Control: no-store` | same (`authTokenBody`) |
| OAuth refresh | `POST /api/v1/oauth/token` JSON `{"grant_type":"refresh_token","refresh_token":"…"}` | `POST /api/v2/oauth/token`; accepts `application/x-www-form-urlencoded` (RFC 6749) **and** JSON |
| OAuth refresh success | `{"access_token","token_type":"bearer","expires_in":<jwtttlshort>,"refresh_token":"<new>"}` | same |

[V] `pkg/routes/api/v1/login.go:RefreshToken`, `pkg/routes/api/v2/auth_refresh.go`, `pkg/routes/api/v2/oauth.go`, `pkg/modules/auth/oauth2server/token.go:exchangeRefreshToken`, `pkg/routes/routes.go:542-553`

**Errors (both refresh styles):**
- 401 with code 16002 (invalid, or already rotated), 16003 (expired), 16004 (lost a concurrent rotation race), 16005 (no cookie sent; cookie endpoint only).
- 412 with code 1020 or 1040 if the account is disabled or locked.
- The cookie endpoint clears the cookie only for 16003 and status errors (`IsUnusableRefreshToken`), not for 16004.
- `client_id` is **not** checked on the refresh grant.

[V] `pkg/models/error.go:2420-2530`, `pkg/modules/auth/auth.go:IsUnusableRefreshToken`

**How a non-browser client uses the cookie flow [V server side; I client side]:**
1. Read `Set-Cookie` from the login response. Dart `package:http` joins multiple `Set-Cookie` headers with commas. Either use `dart:io` `HttpClientResponse.cookies` or dio's list headers, or regex `vikunja_refresh_token=([0-9a-f]+)`. Both cookies carry the same value.
2. To refresh, send `Cookie: vikunja_refresh_token=<value>` to `/api/v2/user/token/refresh` (or v1). The server reads it with `ec.Cookie(...)` and ignores the cookie `Path`.
3. Parse the new `Set-Cookie` on **every** refresh response, because the token rotates.

**Shortcut (≥ 2.3.0) [V]:** `exchangeRefreshToken` calls the same `auth.RefreshSession` against the same `sessions` table. A refresh token obtained from the login cookie can therefore be redeemed at `/oauth/token` with `grant_type=refresh_token`, and from then on the token comes back in the JSON body. The session keeps `is_long_session`.

### 4.4 Session listing and revocation [V] `pkg/routes/api/v2/sessions.go`, `pkg/routes/routes.go:613-620`, `pkg/models/sessions.go`, `sessions_permissions.go`
- List: v1 `GET /api/v1/user/sessions` (array; v1 pagination headers). v2 `GET /api/v2/user/sessions?page=&per_page=` returns `{"items":[Session],"total","page","per_page","total_pages"}` (`pkg/routes/api/v2/types.go:Paginated`). Sorted by `last_active DESC, id DESC`.
- `Session` JSON contains `id`, `device_info`, `ip_address`, `last_active`, `created`. There is no `is_current` flag; compare against the JWT `sid`.
- Revoke: `DELETE /api/v{1,2}/user/sessions/{uuid}`, only for the owner. Link-share tokens are forbidden.
- Revocation fires `SessionsRevokedEvent`, which closes matching WebSockets. [V] `pkg/websocket/listener.go:SessionsRevokedListener`
- **All** of a user's sessions, including the caller's own, are deleted on:
  - password change [V] `pkg/models/user_settings.go:setUserPasswordAndInvalidateSessions`
  - password reset [V] `pkg/routes/api/shared/auth.go:ResetPassword`
  - enabling TOTP [V] `pkg/routes/api/v1/user_totp.go:125`, `pkg/routes/api/v2/user_totp.go:210`
  - admin status change to disabled [V] `pkg/models/admin_user_actions.go:107`
  - account lock [V] `pkg/models/listeners.go:RevokeSessionsOnAccountLock`
  - The app must expect its own refresh token to die after it performs any of these.

---

## 5. The 401 "code 11" contract

**Server [V] `pkg/routes/api_tokens.go`:**
- `ErrCodeInvalidToken = 11`. The echo-jwt `ErrorHandler` returns **401** `{"code":11,"message":"missing, malformed, expired or otherwise invalid token provided"}` whenever the JWT is missing, malformed, badly signed (for example after a secret change) or expired. The body is v1-shaped even on `/api/v2`.
- **API tokens also produce code 11.** If a `Bearer tk_…` token is unknown, expired, belongs to a disabled or locked owner, or lacks the route scope, the Skipper returns false. The JWT middleware then tries to parse `tk_…` as a JWT and fails, which yields 401 code 11. So code 11 means "refresh might help" **only** when the request carried a user JWT (`type == 1`).
- Other 401s carry a different body or code. Examples: v2 `authFromCtx` returns 401 `"invalid or missing authentication"` with no code; refresh failures return 16002–16005.

**Official web client [V]:**
- `frontend/src/client/http.ts:101-158`: on 401 it reads `code`. If `code === 11`, the original token was a user token (`type===1`) and the identity is unchanged, it calls `refreshToken(true)`, which is single-flight. If the stored token is still the one that failed, it refreshes; otherwise it reuses the newer token. It then retries the request **once** with the new token. Link-share 401s are not retried.
- `frontend/src/helpers/auth.ts`:
  - `inFlightRefresh` deduplicates refreshes within a tab.
  - `navigator.locks.request('vikunja-token-refresh')` serializes across tabs. Before the lock it snapshots `localStorage.token`; inside the lock it adopts the stored token if another tab already refreshed.
  - `authEpoch` prevents a refresh that finishes after a logout from re-persisting a token.
  - Failures are classified as `network` / `server`(≥500) / `rate-limited`(429, `Retry-After` capped at 10 min) / `rejected`.
  - After a timed 429, further refreshes are refused until `retryAt`.
  - The refresh uses a separate client without the bearer header or the 401 interceptor (`client/publicClient.ts`) and calls the v2 `authRefreshToken` operation with `credentials:'include'`.
- `frontend/src/stores/auth.ts:refreshTokenWithRetry` retries once more on `server` or `rejected` failures, except code 16005. A race loser then has the rotated cookie. `checkAuth` removes the stored JWT on a rejected 401.
- `frontend/src/composables/useRenewTokenOnFocus.ts`: proactive refresh 60 s before `exp`; refresh on app load; on window focus, refresh immediately if expired or within 60 s of expiry.
- Desktop (Electron) refreshes via IPC to `desktop/oauth.js:refreshAccessToken`, which POSTs `{grant_type:'refresh_token', refresh_token}` to `/api/v2/oauth/token`. The refresh token is stored in `localStorage.desktopOAuthRefreshToken`. [V] `frontend/src/helpers/auth.ts:210-236`

**Retry contract for the app (derived):**
`if (status==401 && body.code==11 && tokenType==user)` then `await singleFlightRefresh()` and retry the original request exactly once. Any 401 on the retry means the session is dead. Never retry non-idempotent requests twice. [I]

---

## 6. Local and LDAP login

**Endpoints** [V] `pkg/routes/routes.go:531-534`, `pkg/routes/api/v1/login.go:Login`, `pkg/routes/api/v2/auth_login.go`:
- `POST /api/v1/login` and `POST /api/v2/login`. Registered only if `auth.local.enabled || auth.ldap.enabled`; otherwise the route returns 404.
- Body (`user.Login`, `pkg/user/user.go:51`): `{"username": "<username or email>", "password": "...", "totp_passcode": "123456", "long_token": true}`. Lookup is by username **or email** (`getUserByUsernameOrEmail`).
- 200 `{"token":"<jwt>"}`, `Cache-Control: no-store`, refresh cookies (§4.2). `long_token:true` makes the session long (30 d sliding).
- The session records `User-Agent` as `device_info`. Send a descriptive UA such as `Vikunja-Flutter/1.0 (Android 15; Pixel 9)` so the sessions list is readable. [V] `IssueUserToken(… c.Request().UserAgent() …)`
- LDAP is tried first with the same body. A successful LDAP bind creates or updates a user with issuer `ldap`. Local accounts keep working alongside it. [V] `pkg/routes/api/shared/auth.go:resolveLoginUser`

**Order of checks and error codes** [V] `pkg/routes/api/shared/auth.go:AuthenticateUserCredentials`, `pkg/user/user.go:CheckUserCredentials`, `pkg/user/error.go`:

| Situation | HTTP | code |
|---|---|---|
| Missing username or password | 400 | 1004. v1 bind failure gives 400 `{"message":"Please provide a username and password."}` |
| Unknown user / wrong password | 403 | 1011. The 3rd consecutive failure emails the user (`handleFailedPassword`) |
| Email not confirmed | 412 | 1012 |
| Account managed by OIDC (issuer not local) | 412 | 1021 |
| Bot account | 412 | 1031 |
| Disabled | 412 | 1020 |
| Locked (after 10 bad TOTPs) | 412 | 1040 |
| **TOTP enabled, `totp_passcode` empty** | **412** | **1017** ("Invalid totp passcode.") |
| TOTP wrong | 412 | 1017. 3rd failure emails the user; 10th locks the account, issues a password-reset email and revokes sessions (`pkg/user/totp.go:HandleFailedTOTPAuth`) |
| TOTP code reused within 90 s | 412 | 1039 (`ValidateTOTPPasscode`) |

The password is verified **before** TOTP, so a 1017 implies the password was correct. The web client shows the TOTP field when it gets `code === 1017` and had sent no passcode, then resubmits everything with `totp_passcode`. [V] `frontend/src/stores/auth.ts:login`, `frontend/src/constants/auth.ts` (`ERROR_CODE_TOTP_REQUIRED = 1017`)

**Rate limit:** 10 requests per minute per IP (`ratelimit.noauthlimit`). This cannot be disabled (§12).

---

## 7. Vikunja as OAuth 2.0 authorization server (≥ 2.3.0): the native-app flow

**Server [V]:**
- `POST /api/v{1,2}/oauth/authorize` **requires a user JWT**. API tokens get 403.
  - Body: `{"response_type":"code","client_id":"<any string>","redirect_uri":"…","state":"…","code_challenge":"<b64url(sha256(verifier))>","code_challenge_method":"S256"}`.
  - Response: `{"code","redirect_uri","state"}`.
  - Sources: `pkg/modules/auth/oauth2server/authorize.go`, `pkg/routes/api/v2/oauth.go`, `pkg/routes/routes.go:585`.
- `redirect_uri` is allowed only if the scheme **starts with `vikunja-`** (any host or path), or it is `http://` on a loopback host (`localhost`, 127.0.0.0/8, ::1). Otherwise the server returns 400 code 17002. [V] `oauth2server/client.go:ValidateRedirectURI`
- There is **no client registry**. `client_id` is free-form and only has to match between authorize and token, otherwise 400 code 17001.
- PKCE is **mandatory**, S256 only (400 code 17003). [V] `pkce.go`, `authorize.go`
- The code is 64 random characters, stored hashed, valid for 10 min and single-use. It is burned even when validation fails. [V] `pkg/models/oauth_codes.go`, `token.go:consumeAuthorizationCode`
- `POST /api/v{1,2}/oauth/token` is public.
  - Authorization-code grant: `{"grant_type":"authorization_code","code","client_id","redirect_uri","code_verifier"}` returns `{"access_token","token_type":"bearer","expires_in":600,"refresh_token"}` and creates a session with `long=false`, `device_info=User-Agent`.
  - Errors: 400 with 17004 (code invalid or used), 17005 (expired), 17006 (PKCE mismatch), 17007 (bad grant).
  - Refresh grant: see §4.3.
  - v2 accepts form-encoded and JSON bodies.
  - Rate limit: `tokenrefreshlimit`, 60/min/IP.
  - [V] `token.go`, `pkg/routes/routes.go:445,555`

**Frontend page [V] `frontend/src/views/user/OAuthAuthorize.vue`, `frontend/src/router/index.ts:437-440, 496-580`, `frontend/src/constants/redirectHash.ts`:**
- Route `/oauth/authorize` requires `response_type, client_id, redirect_uri, code_challenge, code_challenge_method`.
- If the user is not logged in, the router sends them to `/login#redirect=/oauth/authorize?...`. The hash keeps the parameters out of server logs.
- The destination is folded into localStorage so it survives an OIDC round-trip. After any login method (password, LDAP, OIDC, with TOTP) the page loads again.
- On mount it **immediately** POSTs `/oauth/authorize` (there is **no consent screen**) and sets `window.location.href = redirect_uri?code=…&state=…`.

**Reference clients [V]:**
- `desktop/oauth.js`: `CLIENT_ID='vikunja-desktop'`, `REDIRECT_URI='vikunja-desktop://callback'`. Verifier is 32 random bytes in base64url; challenge is base64url(sha256). Authorize URL is `<server>/oauth/authorize?...` (served by the frontend). Token endpoint is `<server>/api/v2/oauth/token` with JSON. The Electron login page shows *only* this flow. [V] `frontend/src/views/user/Login.vue:19`, `DesktopLogin.vue`
- `veans/internal/auth/oauth.go`: `client_id='veans-cli'` with a loopback `http://127.0.0.1:<port>/callback` redirect.

**Mobile recipe [V for the server contract; I for the platform]:**
1. `GET /api/v1/info` and read `frontend_url`. This is `service.publicurl`, always ending in `/`. If it is empty, use the server origin the user entered.
2. Generate `verifier` (32–96 bytes, base64url), `challenge`, and a random `state`.
3. Call `FlutterWebAuth2.authenticate(url: "${frontend_url}oauth/authorize?response_type=code&client_id=vikunja-flutter&redirect_uri=vikunja-flutter%3A%2F%2Fcallback&code_challenge=…&code_challenge_method=S256&state=…", callbackUrlScheme: "vikunja-flutter")`.
   - On iOS this uses ASWebAuthenticationSession (shares Safari cookies unless ephemeral).
   - On Android it uses a Custom Tab plus `CallbackActivity` with an intent-filter for the scheme.
4. Verify `state`, then POST the code exchange to `/api/v2/oauth/token`, or `/api/v1/oauth/token` on 2.3.x.
5. Pick a unique scheme. It must start with `vikunja-`. Avoid `vikunja-desktop` to prevent collisions. PKCE protects against code interception by another app claiming the same scheme.

**Caveats:**
- **Sessions from the code grant are never long.** They die after 72 h without a refresh (`jwtttl`, which admins can raise). [V] `token.go:CreateSession(..., false, nil)`
- An OIDC session created *inside the browser* stores the OIDC `id_token` on the browser's session. The OAuth-issued app session has none, so app logout returns no `oidc_logout_url`. [V] `CreateSession(... nil)`
- **No consent screen:** any local app that claims a `vikunja-*` scheme can silently obtain a token for a user who is already logged in to the web UI in the system browser. This is a server-side weakness, not the app's problem. [I]

---

## 8. OpenID Connect (third-party IdP) login

**What `/info` exposes** [V] `pkg/routes/api/shared/info.go`, `pkg/modules/auth/openid/openid.go:Provider`, `providers.go:337-373`:
```json
"auth": { "local": {"enabled":true,"registration_enabled":true},
          "ldap": {"enabled":false},
          "openid_connect": {"enabled":true, "providers":[
             {"name":"Authentik","key":"authentik","auth_url":"<IdP authorization_endpoint from discovery>",
              "logout_url":"<static logouturl or empty>","client_id":"<vikunja client id>","scope":"openid email profile",
              "email_fallback":false,"username_fallback":false,"force_user_info":false}]}}
```
`auth_url` is the **discovered** `authorization_endpoint`. The `authurl` config key is the issuer.

**Web flow [V] `frontend/src/helpers/redirectToProvider.ts`, `frontend/src/views/user/OpenIdAuth.vue`, `frontend/src/stores/auth.ts:openIdAuth`:**
1. The frontend builds `redirect_uri = <current origin><base>auth/openid/<key>`. It deliberately does not use a server-provided URL, "to allow redirects when using the electron app".
2. It stores a random `state` in localStorage and navigates to `${auth_url}?client_id=${client_id}&redirect_uri=${redirectUrl}&response_type=code&scope=${scope}&state=${state}`. There is no PKCE and no nonce.
3. The IdP redirects to `<frontend>/auth/openid/<key>?code=…&state=…`. The frontend checks `state`.
4. The frontend POSTs `{"code":"…","redirect_url":"<same redirect uri>","totp_passcode"?}` to `POST /api/v2/auth/openid/{provider}/callback`. The v1 equivalent is `POST /api/v1/auth/openid/{provider}/callback`, registered only if `auth.openid.enabled`. [V] `pkg/routes/routes.go:536-538`, `pkg/routes/api/v2/auth_openid.go`
5. Response: 200 `{"token"}` plus refresh cookies. The session is **never long**, and the `id_token` is stored for RP-initiated logout.

**Server code exchange [V] `pkg/modules/auth/openid/openid.go:exchangeOidcTokens`:**
- `provider.Oauth2Config.RedirectURL = cb.RedirectURL`, then `Oauth2Config.Exchange(ctx, cb.Code)` as a **confidential client** (client id + **secret**) with **no `code_verifier`**. The ID token is verified with `oidc.Verifier{ClientID}`.
- The server does **not** validate `redirect_url` against anything; the IdP does that. The `redirect_url` must equal the `redirect_uri` sent in the authorization request and be registered at the IdP for Vikunja's client id.
- The server does not check `state`. That check is purely client-side.
- Errors:
  - v1 returns 400 `{"message":"Could not authenticate against third party.","details":{…IdP error JSON…}}`.
  - v2 returns 400 problem+json with the details in `errors[0].value`.
  - Unknown provider: 400 code 15001 "Provider does not exist" (v1 `ErrOpenIDBadRequest`).
  - Missing email: 412 code 1019.
  - Disabled or locked account: 1020 / 1040.

**TOTP with OIDC (≥ 2.3.0) [V] `openid.go:Callback` comment (GHSA-8jvc-mcx6-r4cg), `OpenIdAuth.vue`:**
- If the resolved user has TOTP enabled and no or a wrong `totp_passcode` was sent, the callback returns 412 code 1017.
- The IdP code is single-use, so the client must **restart the whole IdP flow** and send the new code together with `totp_passcode`. The web client stashes the passcode in sessionStorage and redirects to the provider again.

**Logout [V] `pkg/routes/api/shared/auth.go:LogoutSession`, `pkg/modules/auth/openid/logout.go`:**
- For OIDC sessions, logout returns `oidc_logout_url`: the IdP `end_session_endpoint` with `id_token_hint`, `client_id` and `post_logout_redirect_uri = service.publicurl`.

**Can a mobile app use native OIDC?**
- **Custom scheme (`app.vikunja://callback`):** this works only if the admin adds that redirect URI to the IdP client that Vikunja uses. That client is confidential and owned by the server, and some IdPs (for example Google "Web application" clients) do not allow custom schemes at all. The app sends `redirect_url=app.vikunja://callback` and the server forwards it. **Not portable across self-hosted instances.** [V server-side behaviour; I IdP behaviour]
- **PKCE:** **not supported** in the IdP leg, because the server never sends a `code_verifier`. If the app added a `code_challenge` to the authorize URL, a compliant IdP would reject the exchange. [V absence in `exchangeOidcTokens`; I IdP behaviour]
- **Intercepting `https://<frontend>/auth/openid/<key>`:**
  - ASWebAuthenticationSession completes only on a custom scheme. The https callback on iOS 17.4+ requires Associated Domains on the user's host.
  - Android Custom Tabs need verified App Links (`assetlinks.json`) on the user's host.
  - Both are infeasible for arbitrary self-hosted domains.
  - Only an **embedded WebView** (`flutter_inappwebview` + `shouldOverrideUrlLoading`) can intercept it. RFC 8252 discourages that, many IdPs block it (for example Google's `disallowed_useragent`), and passkeys and password managers degrade. [I]
- **Recommendation:**
  - On ≥ 2.3.0, never do OIDC natively. Use §7: the frontend performs OIDC on its already-registered redirect URI inside the system browser, and the app only ever sees a Vikunja code on a `vikunja-*` scheme.
  - On < 2.3.0, offer the embedded-WebView interception as a best-effort fallback (labelled "may not work with all providers"). After intercepting, POST `{code, redirect_url:"<frontend>/auth/openid/<key>"}` to `/api/v1/auth/openid/<key>/callback` and capture the refresh cookie.

---

## 9. API tokens

**Format and storage [V] `pkg/models/api_tokens.go`:**
- Format is `tk_` followed by 40 hex characters (20 random bytes). The DB stores a sha256 (with a legacy PBKDF2 fallback). The cleartext is returned **once** in the create response.

**Endpoints [V] `pkg/routes/routes.go` ("API Tokens"), `pkg/routes/api/v2/api_tokens.go`:**
- v1: `GET /api/v1/tokens`, `PUT /api/v1/tokens` (create), `DELETE /api/v1/tokens/{id}`.
- v2: `GET /api/v2/tokens?page&per_page&s&owner_id`, `POST /api/v2/tokens` (201), `DELETE /api/v2/tokens/{id}`.
- Create body: `{"title":"Phone","permissions":{"tasks":["read_all","update"],"projects":["read_all"]},"expires_at":"2027-01-01T00:00:00Z","owner_id"?: <bot id>}`. `expires_at` is **required**. There is no "never" option; the frontend defaults to 30 days or a custom future date. [V] `frontend/src/components/token/ApiTokenForm.vue:47-71,269-279`
- Expiry notifications have been sent by cron since 2.3.0.

**Scopes [V] `pkg/models/api_routes.go`:**
- `GET /api/v{1,2}/routes` returns `{group: {permission: {"path","method"}}}`.
- Groups come from the path with the version prefix stripped and `/` replaced by `_`. Permissions are `read_all`, `read_one`, `create`, `update`, `delete` and `*_bulk`. Non-CRUD sub-routes get custom keys, for example `projects.background`, and single-segment non-CRUD routes go under `other`.
- v1 and v2 share keys: v2 `POST` maps to `create`, v1 `PUT` maps to `create`, and v2 `PATCH` is accepted where the grant is a `PUT` "update".
- Matching is exact on (method, route template). `GET /tasks` and `/projects/:project/tasks` both match `tasks.read_all`.
- Special groups: `caldav.access`, `feeds.access`, `mcp.access`.
- `expand=comments|comment_count|reactions|time_entries_count` additionally needs `tasks_comments.read_all`, `reactions.read_all` or `time_entries.read_all` (GHSA-9rg3-v78m-26q8).

**Never grantable to API tokens [V] `CollectRoutesForAPITokenUsage`:**
- Groups `token_test` (special-cased as allowed), `subscriptions`, `tokens`, `oauth_authorize`, `mcp*`, and **every `user_*` route**. That covers `/user/settings/*`, `/user/sessions`, `/user/password`, `/user/deletion/*`, `/user/export/*`, `/user/settings/totp*`, `/user/timezones`, `/user/bots` and `/user/token`.
- `GET /user` and `GET /users` are allowed via `other.user` / `other.users`.

**Implications for using an API token as an app login:**
- Requests fail with 401 code 11 when out of scope (§5), which is indistinguishable from an expired token.
- **No WebSocket**: `ParseUserToken` requires a JWT with `type==1` and a `sid`. [V] `pkg/websocket/connection.go:handleAuth`, `pkg/modules/auth/auth.go:ParseUserToken`
- No subscriptions, so the app cannot subscribe to tasks or projects.
- No user settings (language, timezone, default project, reminder settings), no session management, no TOTP, no CalDAV-token management.
- No OAuth authorize (403).
- Tokens expire hard at `expires_at`, with no refresh.
- **Verdict:** offer it only as an "advanced: paste API token" option for scripted or limited setups. Show a capability warning, ask for a broad scope set, and validate with `GET /api/v{1,2}/token/test`, which is exempt from the route check (v1 GET returns 200 `{"message":"ok"}`, v1 POST returns 418, v2 GET/POST return 200). [V] `pkg/routes/api_tokens.go:shouldSkipRouteCheck`, `pkg/routes/api/v1/token_check.go`, `pkg/routes/api/v2/token_meta.go`

---

## 10. Link-share authentication

[V] `pkg/routes/api/shared/auth.go:AuthenticateLinkShare`, `pkg/routes/api/v1/link_sharing_auth.go`, `pkg/routes/api/v2/auth_public.go:authLinkShare`, `pkg/models/link_sharing.go`, `pkg/models/error.go:2251-2310`

- The share URL format is `<frontend>/share/<hash>/auth[?view=<viewId>&logoVisible=…]`. [V] `frontend/src/router/index.ts:212`, `frontend/src/views/sharing/LinkSharingAuth.vue`
- `POST /api/v{1,2}/shares/{hash}/auth`, body `{"password":"…"}`. In v2 the body is optional.
  - Response: `{"token":"<link-share JWT>","id","hash","name","permission":0|1|2,"sharing_type":0|1|2,"password":"","shared_by":{…},"created","updated","project_id":<id>}`.
  - Errors: 412 code 13001 (password required), 403 code 13002 (wrong password), 404 code 3006 (share hash not found).
  - Only registered if `service.enablelinksharing` is set (`/info.link_sharing_enabled`). Rate-limited by `noauthlimit`.
- The JWT lives `jwtttl` (72 h). Renew it with `POST /api/v1/user/token` or `POST /api/v2/user/token` using the link-share JWT. A user JWT gets 400 there.
- There is no refresh token or session. When the JWT expires, re-authenticate with the hash and password.
- Link-share tokens get no WebSocket and no `/user`. The web client does not retry 401s for link shares.

---

## 11. Registration, password reset, email confirmation, account deletion, TOTP management

All of the public flows below share the `noauthlimit` (10/min/IP) budget.

| Flow | v1 | v2 | Body → response | Notes |
|---|---|---|---|---|
| Register | `POST /api/v1/register` | `POST /api/v2/register` (201) | `{"username"(3-250, no spaces),"password"(8-72),"email","language"?}`; v2 also accepts `invite_token`. Returns `user.User` | Only if `auth.local.enabled`. Returns 404 if `service.enableregistration=false`; v2 still allows `invite_token`. Does **not** log in: the web client calls `login()` afterwards. If the mailer is on, the user is `email_confirmation_required` and login returns 412/1012. [V] `pkg/routes/api/v1/user_register.go`, `pkg/routes/api/v2/auth_public.go`, `pkg/user/user.go:243`, `frontend/src/stores/auth.ts:register` |
| Request reset | `POST /api/v1/user/password/token` | `POST /api/v2/user/password/token` | `{"email"}` → `{"message":"Token was sent."}` | 404 (1005) if no such email. Email link is `<publicurl>?userPasswordReset=<token>` [V] `pkg/user/notifications.go:128` |
| Reset | `POST /api/v1/user/password/reset` | `POST /api/v2/user/password/reset` | `{"token","new_password"}` | Invalid token: 412/1009. **Kills all sessions.** |
| Confirm email | `POST /api/v1/user/confirm` | `POST /api/v2/user/confirm` | `{"token"}` | Link is `<publicurl>?userEmailConfirm=<token>`. Invalid token: 412/1010 |
| Change password | `POST /api/v1/user/password` | `/api/v2/user/password` | `{"old_password","new_password"}` | **Kills all sessions, including the caller's.** The app must re-login. |
| Delete account | `POST /api/v1/user/deletion/request` / `confirm` / `cancel` | `/api/v2/user/deletion/{request,confirm,cancel}` | request/cancel take `{"password"}` (local users only); confirm takes `{"token"}` | Only if `service.enableuserdeletion` (`/info.user_deletion_enabled`). Email link is `<publicurl>?accountDeletionConfirm=<token>`. [V] `pkg/routes/api/v1/user_deletion.go`, `pkg/user/notifications.go:232` |
| TOTP | `GET /user/settings/totp`, `POST …/totp/enroll`, `POST …/totp/enable` `{"passcode"}`, `POST …/totp/disable` `{"password"}`, `GET …/totp/qrcode` | same paths on v2 | Enable **kills all sessions** | Only if `service.enabletotp`. [V] `pkg/routes/routes.go:631-637` |

All email links point to the web frontend. A self-hosted domain cannot be App-Link-verified for the app [I]. The app should either let the user paste the token from the link or delegate these flows to the browser.

---

## 12. Logout

- v1: `POST /api/v1/user/logout`. v2: `POST /api/v2/logout`. Both **require a valid JWT** (401 code 11 if expired, so refresh first).
- The server deletes the session named by the JWT `sid`, clears the cookies, and returns `{"message":"Successfully logged out.","oidc_logout_url"?}`. For API tokens and link shares it is a no-op.
- [V] `pkg/routes/api/v1/login.go:Logout`, `pkg/routes/api/v2/auth_login.go:authLogout`, `pkg/routes/api/shared/auth.go:LogoutSession`
- Alternatively, `DELETE /user/sessions/{sid}`.
- The access token stays valid for HTTP until `exp` (§3).

---

## 13. Rate limiting

[V] `pkg/routes/rate_limit.go`, `pkg/routes/routes.go`, `config-raw.json` `ratelimit.*`

| Limiter | Scope | Default | Can be disabled? |
|---|---|---|---|
| `noauthlimit` | Per IP, 60 s. One shared instance for v1 and v2 `/login`, `/register`, `/user/password/token`, `/user/password/reset`, `/user/confirm`, `/auth/openid/:p/callback`, `/shares/:share/auth`, `/invite-links/check`, **and both `/ws` upgrades** | 10/min | No |
| `tokenrefreshlimit` | Per IP: `/user/token/refresh` and `/oauth/token`, v1 and v2 | 60/min | No |
| `basicauthlimit` | Per IP, **failed** BasicAuth only (CalDAV, `/feeds`, `/api/v2/notifications.atom`) | 10/min | No |
| Global (`ratelimit.enabled`) | Authenticated v1 and v2 routes, keyed `user_<id>` (`kind=user`, so all of a user's devices share one budget) or by IP; unauthenticated requests fall back to `ip_<ip>` | off; 100 per 60 s | Yes |

- Headers on limited routes: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` (unix seconds).
- On a limit hit: **429** with `Retry-After: <seconds>` and body `{"message":"Too Many Requests"}` (v1 shape, also on v2).
- Mobile implications:
  - Back off WebSocket reconnects, because the upgrade consumes the login budget for that IP. Carrier NAT may share IPs. [I]
  - Honour `Retry-After` on refresh, as the web client does (capped at 10 min).
  - Serialise background sync bursts when `X-RateLimit-Remaining` is low.

---

## 14. WebSocket authentication

[V] `pkg/websocket/{handler,connection,messages,listener,hub}.go`, `frontend/src/composables/useWebSocket.ts`

- The upgrade is `GET /api/v1/ws` (≥ 2.3.0) or `GET /api/v2/ws` (≥ 2.4.0). It is unauthenticated and rate-limited by `noauthlimit`.
- `OriginPatterns = cors.origins`. A native client without an `Origin` header is accepted by coder/websocket. [I]
- The client must send `{"action":"auth","token":"<user JWT>"}` within **30 s**, otherwise the server closes with status 1008 "auth timeout".
- The server accepts **only user JWTs** (`type==1`, non-empty `sid`, valid signature and exp) **and checks that the session exists and the user is active**.
  - Success: `{"action":"auth.success","success":true}`.
  - Rejected token: `{"error":"invalid_token"}` and the socket is closed. The web client treats this as terminal and stops reconnecting.
  - Transient DB error: close code 1013 (TryAgainLater) with no message.
- The server closes the socket at the JWT `exp` ("token expired"). To extend it, send another `{"action":"auth","token":"<new JWT>"}` on the open socket. It must be the **same user and same `sid`**, otherwise the socket gets `invalid_token`. The web client re-auths after every refresh (`onTokenRefreshed(reauthenticate)`) and refreshes before reconnecting if the token expires within 5 s.
- Revoking a session or all sessions closes matching sockets ("session revoked").
- Subscribe with `{"action":"subscribe","event":"notification.created"|"timer.created"|"timer.updated"|"timer.deleted"}`. Unknown events return `{"error":"invalid_event","event":…}`; subscribing before auth returns `{"error":"auth_required"}`.
- Pushes look like `{"event":"…","data":{…}}`. Pings go out every 30 s.
- **There are no task-change events.** The WebSocket cannot drive task sync, only notifications and timers.

---

## 15. Recommended auth design for the Flutter app

### 15.1 Login options (in order of preference)
1. **"Sign in with your Vikunja server" via OAuth + PKCE** (§7). Use it when the OAuth server exists (≥ 2.3.0). It covers local, LDAP, OIDC and TOTP with zero native code per method.
   - Use `flutter_web_auth_2` with `callbackUrlScheme: 'vikunja-<appid>'`. Do not set `preferEphemeral`, so an existing web login in Safari or Chrome is reused.
   - On ≥ 2.4.0 use `/api/v2/oauth/token` with form or JSON. On 2.3.x use `/api/v1/oauth/token` with JSON.
2. **Native username/password form** (local or LDAP, when `/info.auth.local.enabled || ldap.enabled`).
   - `POST /api/v2/login` (or v1 on < 2.4) with `long_token: true`. The session gets a 30-day sliding window, which matters for background sync.
   - On 412/1017 show the TOTP field and resubmit; map 1039, 1040, 1012, 1020 and 1021 to clear messages.
   - Extract `vikunja_refresh_token` from `Set-Cookie`. On ≥ 2.3.0, refresh via `/oauth/token` with `grant_type=refresh_token` (body-based). On 2.0–2.2 use the `Cookie` header against `/api/v1/user/token/refresh`.
3. **Pre-2.0 servers:** `POST /api/v1/login` with `long_token:true` returns a long-lived JWT (`jwtttllong`). Renew it with `POST /api/v1/user/token` before expiry. This is the behaviour since 0.10 per `CHANGELOG.md`; the old handler was not verified because only `main` is checked out. [I]
4. **Advanced:** paste an API token (§9 limitations; no WebSocket and no subscriptions).
5. **Link share:** "Open a shared link" (§10). It is a separate account type with read-only or limited capabilities.
6. Show provider buttons from `/info` only as hints that "Sign in with browser" supports them. Do not start native OIDC except as the < 2.3 WebView fallback (§8).

### 15.2 What to store (per account, in secure storage)
- Key: `accountId = sha256(normalizedServerRoot + '|' + userId)`. Take `userId` from the JWT `id` claim, or use `share:<hash>` for link shares.
- Secure storage (Keychain or Android Keystore-backed), **per account:**
  - `refreshToken`: the most sensitive item.
  - `accessToken`: optional; it can live in memory and be re-minted.
  - `apiToken` or link-share `password`, depending on the account type.
- iOS: `KeychainAccessibility.first_unlock_this_device` (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), so background fetch and notification actions work while the device is locked. Add a keychain **access group / App Group** only if the widget extension must authenticate itself (prefer that it does not, see below).
- Android: `flutter_secure_storage` (Keystore-wrapped AES). Exclude it from Auto Backup (`android:allowBackup="false"` or backup rules).
- Non-secret metadata (in the app database): `serverRoot`, `frontendUrl`, `apiCapabilities{v2, oauth, sessions}`, `authMethod` (`oauth|password|ldap|apitoken|linkshare|legacy`), `isLongSession`, `sid`, `username`, `accessTokenExp`, `serverClockOffset = iat - localNow` at receipt, and `lastRefreshAt`.

### 15.3 Refresh strategy
- Compute expiry with the server clock offset. Refresh **proactively** when `exp - serverNow < 60 s` before a request, and **reactively** on 401 code 11 (one refresh, one retry). This mirrors `useRenewTokenOnFocus.ts` and `client/http.ts`.
- The 72 h inactivity window applies to OAuth and OIDC sessions. The background worker should refresh at least every ~24 h even when idle: Android WorkManager periodic, iOS `BGAppRefreshTask` (best-effort). If a refresh returns 16003 or 16002, mark the account `needsReauth` and post a local notification ("Sign in again to keep syncing"). Do not clear cached data. [I]
- Classify failures the way `helpers/auth.ts` does:

  | Failure | Action |
  |---|---|
  | `network` | Keep the tokens, retry later |
  | `server` (≥ 500) | Retry once |
  | 429 | Wait for `Retry-After` |
  | 401 code 16004 | Re-read storage; a sibling probably won |
  | 401 code 16002 / 16003 / 16005, or 412 code 1020 / 1040 | Session dead |

- **Write-ahead for rotation.** Persist the new refresh token to secure storage **before** using the new access token or doing anything else, so a crash after the response still keeps the rotated token. Because the server has no reuse grace period (§4.1), make the refresh HTTP call non-cancellable: no short timeouts, and do not start it inside an iOS BG task with only a few seconds left. [I]

### 15.4 Concurrency-safe refresh
- In each isolate, keep a single-flight `Future<void>? _inFlight` per account.
- Across isolates and processes (UI isolate, WorkManager isolate, notification-action background isolate on Android, iOS background handlers), use a **per-account exclusive file lock**: `RandomAccessFile.lock(FileLock.blockingExclusive)` on `<appSupport>/auth/<accountId>.lock`. On iOS, put the lock file in the App Group container if extensions participate.
- Under the lock:
  1. Re-read `refreshToken` from storage.
  2. If it differs from the token the caller started with, adopt the stored access token and return. This is the same pattern as `tokenBeforeLock` in `frontend/src/helpers/auth.ts`.
  3. Otherwise call the server, persist the result, then release the lock.
- Keep an **auth epoch** per account (as `authEpoch` does) so that a refresh completing after logout or account switch is discarded.
- **Widgets** (Android `home_widget`, iOS WidgetKit) should **not** hold credentials. They render a snapshot written by the app or worker to shared storage (App Group / SharedPreferences). Interactive "mark done" from a widget or notification enqueues an outbox entry and triggers the worker. If an immediate call is needed, it goes through the same locked refresh path in the main app process (Android BroadcastReceiver → headless isolate; iOS `UNNotificationAction` with `.authenticationRequired` off → app background launch). [I]

### 15.5 Multi-account readiness
- Each login creates an independent server session, so N accounts on the same or different servers coexist. Use one HTTP client and interceptor instance per account (base URL plus token provider), and keep a separate DB, cache and notification namespace per account.
- Do not share cookie jars between accounts. If the cookie flow is used, keep the refresh cookie value in that account's secure entry, not in a global jar.
- On switch: close that account's WebSocket, because a socket is bound to user+sid and must be torn down, as the web client does in `setSession` → `closeStaleConnection`.
- Detect duplicates: the same `serverRoot` and `userId` means the same account; replace the old session and revoke it.

### 15.6 Logout and revocation
1. Ensure a valid access token (refresh if needed), then call `POST /api/v2/logout` (v1: `/api/v1/user/logout`). This is best-effort; ignore network errors, as the web client does.
2. Cancel workers, scheduled notifications and widget data for the account. Close the WebSocket. Wipe secure entries and the account DB. Bump the auth epoch.
3. If `oidc_logout_url` is present (native OIDC fallback sessions only), optionally open it with an ephemeral in-app browser.
4. Note that the OAuth flow leaves a web login in the system browser. Optionally offer "also sign out of the browser" by opening `<frontend>` logout. [I]
5. "Sign out other devices": `GET /api/v2/user/sessions` and `DELETE` each one except the current `sid`. Show `device_info`, `ip_address` and `last_active`.
6. Remote revocation (password change or reset, TOTP enable, admin disable, lock) shows up as refresh 401 16002, or 412 1020/1040, or WebSocket `invalid_token` / close "session revoked". Treat all of them as `needsReauth`.
7. After the app itself changes the password or enables TOTP, immediately run the login flow again, because the server just deleted the app's own session too.

### 15.7 Security notes
- Pin TLS? No: users self-host with arbitrary certificates. Do allow user-installed CAs on Android via network security config for self-hosted setups. Warn on `http://` servers, because tokens are sent in clear text. [I]
- Never log the `Authorization`, `Cookie` or `Set-Cookie` headers, or OAuth codes. Use `Cache-Control: no-store` responses as-is.
- Validate the OAuth `state`. Use a fresh PKCE verifier per attempt and discard it after one use, as `desktop/oauth.js` does.

---

## 16. Unverified or open points
- Exact behaviour of the old pre-2.0 `POST /api/v1/user/token` for user JWTs: inferred from CHANGELOG 0.10 only, since only `main` is available.
- Whether every self-hosted reverse proxy forwards `/oauth/authorize` to the SPA. It is a frontend route served by the same binary in default setups (`setupStaticFrontendFilesHandler`); separate-frontend deployments must serve it too. [I]
- The coder/websocket Origin handling for clients without an Origin header is library behaviour that was not checked in vendored code. [I]
- `huma` behaviour when the OAuth authorize handler returns an `echo.HTTPError` (for example "response_type must be 'code'"): it may surface as 500 on v2. Not tested. [I]
