# Research snapshot

The files in this directory are the research snapshot of **2026-10-08**. They were written against Vikunja `main` @ `e7d7f17` (2026-10-06), whose latest release is **v2.7.0**. They are kept as written and are not updated. Later findings are recorded below.

**Precedence:**
1. Where the files disagree, **[critique.md](critique.md) wins** over the other research files.
2. [synthesis.md](synthesis.md) already applies the critique's corrections. It is the basis for [../architecture.md](../architecture.md), [../roadmap.md](../roadmap.md), [../decisions.md](../decisions.md) and [../open-questions.md](../open-questions.md).
3. The corrections below win over all research files.

| File | Contents |
|---|---|
| [api-v1.md](api-v1.md) | `/api/v1` (Echo): endpoints, conventions, errors, paging |
| [api-v2.md](api-v2.md) | `/api/v2` (Huma, ≥ 2.4.0): endpoints, AutoPatch, ETag, problem+json, `/info` |
| [auth.md](auth.md) | Login, sessions and refresh, OAuth 2.0 + PKCE, API tokens, WebSocket auth |
| [sync.md](sync.md) | Delta sync, deletes, outbox, conflicts, server limits |
| [features.md](features.md) | Feature inventory of the web frontend |
| [client-logic.md](client-logic.md) | Client-side logic to port: quick-add, filters, dates, positions, colours |
| [flutter-stack.md](flutter-stack.md) | Flutter packages and versions, native configuration, build experiments |
| [critique.md](critique.md) | Completeness review: corrections, gaps, unverified claims |
| [synthesis.md](synthesis.md) | Architecture, roadmap, open questions and risks derived from all of the above |

## Later research

Written after the snapshot, against the release named in each file:

| File | Contents |
|---|---|
| [trash.md](trash.md) | The trash of Vikunja 2.8.0: routes, lists, counts, restore, permanent delete, retention, and the web's behaviour (2026-11-09) |

## Corrections found since

Items 1 and 2 were verified against the Docker test servers in [`test_servers/`](../../test_servers/docker-compose.yaml) (images `vikunja/vikunja:1.0.0`, `2.0.0`, `2.3.0`, `2.4.0`, `2.7.0`) and against `try.vikunja.io`. The responses are recorded in `packages/vikunja_api/test/fixtures/`.

1. **`concurrent_writes` has existed since 2.4.0.**
   - It is present in `/api/v1/info` and `/api/v2/info` of the 2.4.0 image, and `false` on SQLite.
   - It is absent from the 2.3.0 image.
   - This replaces api-v2.md's "likely unreleased (post-2.7.0 main)" and answers critique.md §4 item 7.
   - A missing field still means "unknown", so writes are serialized.
2. **`/api/v2/info` on servers older than 2.4.0 returns 404 with JSON.**
   - The status is 404, with `Content-Type: application/json` and the body `{"message":"Not Found"}`. This was checked on 1.0.0, 2.0.0 and 2.3.0.
   - A JSON content type therefore does not mean v2 is available. Only a 200 with a string `version` does, as synthesis.md §2.4 requires.
   - This 404 must lead to the `/api/v1/info` probe. It must not be classified as "not Vikunja" or "behind a login proxy".
3. **iOS must not get `NSAllowsLocalNetworking` while `NSAllowsArbitraryLoads` is needed.**
   - synthesis.md §3 lists `NSAllowsLocalNetworking` for the iOS configuration, and step 35 plans a "per-host cleartext opt-in".
   - iOS ignores `NSAllowsArbitraryLoads` as soon as `NSAllowsLocalNetworking` is present, and ATS exception domains cannot name hosts typed at runtime.
   - The per-host opt-in is therefore the in-app confirmation only; the OS keys stay open. See [D8](../decisions.md#d8-cleartext-policy).

Items 4 to 9 were verified during step 2+3 against the 2.3.0, 2.4.0 and 2.7.0 Docker images, by the contract tests in `packages/vikunja_api/test/contract/auth_contract_test.dart` and the captures in `packages/vikunja_api/test/fixtures/errors/` and `fixtures/user/`. They correct [auth.md](auth.md).

4. **Access tokens from 2.3.0 and 2.4.0 have no `iat` claim** (auth.md §3).
   - 2.7.0 sends `iat`; the access tokens of 2.3.0 and 2.4.0 lack it.
   - `JwtClaims.issuedAt` is therefore optional. The token client derives the issue time as `exp − expires_in` (600 s when `expires_in` is missing), which is still server time, so the clock offset works on every supported version.
5. **Refresh errors on 2.3.0 and 2.4.0 carry no code** (auth.md §4.3).
   - A rotated or unknown refresh token gives 401 with only a message: v1 `{"message":"Invalid or expired refresh token."}`, v2 problem+json without `code`. 2.7.0 sends code 16002.
   - On the public token endpoint any 401 therefore means the refresh token is unusable (`SessionEnded`).
6. **Before 2.7.0, `/api/v1/oauth/token` shares the login limiter** (auth.md §7, §13).
   - On 2.3.0 and 2.4.0 the v1 token endpoint counts against the same 10 per minute and IP as `/login` and `/register`. The 429 has `X-RateLimit-Limit: 10` and `X-RateLimit-Reset`, but no `Retry-After`; the wait is computed from `X-RateLimit-Reset` and the server's `Date` header.
   - The v2 token endpoint on 2.4.0 had no limit. Only 2.7.0 has the separate `tokenrefreshlimit` of 60 per minute.
   - On 2.3.x, where the app has only the v1 endpoint, a refresh can therefore be refused because of unrelated logins from the same IP (carrier NAT). The session manager keeps the tokens and refuses further refreshes until the limit resets (capped at 10 min).
7. **A lost rotation race never produced 16004 on these SQLite servers** (auth.md §4.1, §4.3).
   - When several refreshes send the same token at once, the losers get 500 `Internal Server Error` or 401 (16002 on 2.7.0, no code before).
   - A 500 on refresh can thus be a lost race. The session manager re-reads storage before it retries and adopts a newer token if a sibling stored one.
   - There is still no reuse detection: an old refresh token gets 16002 and the session lives on (confirms §4.1).
8. **2.3.0 and 2.4.0 do not burn a code that fails the token checks** (auth.md §7).
   - After a failed PKCE (17006), `client_id` (17001) or `redirect_uri` (17002) check, the same code still works with the right values on 2.3.0 and 2.4.0. 2.7.0 burns it, as §7 says.
   - The token step checks both `client_id` and `redirect_uri` on all three versions.
9. **`GET /user` does not return the email address** (api-v1.md, api-v2.md).
   - The own user record has no `email` field on 2.3.0, 2.4.0 or 2.7.0. `User.email` stays null; the app shows the username and display name only.

Item 10 comes from the step 2+3 security review and was read from the source.

10. **A reused web login is the app's problem too** (auth.md §7 "No consent screen", §15.1).
    - The authorize callback carries only `code` and `state`, no RFC 9207 `iss` (`frontend/src/views/user/OAuthAuthorize.vue:65-71`), and there is no consent screen.
    - A malicious server can therefore point the app at another server's authorize page. With the browser's web login reused, that server issues a code silently, and the app hands it and the PKCE verifier to the malicious server's token endpoint.
    - The app therefore uses an ephemeral browser session, contrary to §15.1 ([D23](../decisions.md#d23-browser-sign-in-through-flutter_web_auth_2-client-id-and-redirect-uri)).

Item 11 comes from the step 35b research and was read from the dio 5.11.1 and Dart SDK sources.

11. **dio's `validateCertificate` cannot pin a certificate** (flutter-stack.md §3.4).
    - It runs after the request was sent and the response headers arrived, and only for a chain the `SecurityContext` already accepted: a self-signed server fails before it is asked, and an impostor would get the token first.
    - The app pins in the TLS handshake instead, and one adapter in the base `Dio`s sends only pinned, CA-trusted and client-certificate servers through `dart:io` ([D65](../decisions.md#d65-connection-settings-per-server-address-in-the-apps-transport-a-certificate-pinned-in-the-tls-handshake-or-a-trusted-ca-certificate-a-client-certificate-access-headers-and-unencrypted-connections-only-with-consent-failing-closed)).

Item 12 comes from the step 35c audit and was read from Android's documentation on Auto Backup and on the backup changes of Android 12.

12. **`android:allowBackup="false"` does not stop a device-to-device transfer** (auth.md §15.2, synthesis.md §2.5 and §3).
    - For an app targeting Android 12 or later it turns cloud backup off, but on devices of some manufacturers not a transfer to a new phone. That takes `android:dataExtractionRules` with a `<device-transfer>` section; below Android 12 `allowBackup="false"` covers both.
    - The app excludes everything from both since step 35c ([D66](../decisions.md#d66-a-threat-model-uncaught-errors-redacted-and-never-printed-in-release-builds-the-apps-data-out-of-backups-and-device-transfer-routes-pushed-by-the-platform-taken-only-as-app-scheme-links-widget-links-and-notification-taps-switching-accounts-only-with-a-per-install-key-exported-components-and-dependencies-checked-in-ci)).

## Confirmed on live servers

These statements in the research files are now confirmed:
- `/api/v1/info` and `/api/v2/info` return the same body; v2 adds `$schema`.
- `/api/v1/info` already answers on 1.0.0, with the same shape minus the 2.4.0 additions.
- `enabled_pro_features` and `allow_icon_changes` also appear first in 2.4.0; they are absent in 2.3.0.
- `registration_enabled` lives under `auth.local`, not at the top level.
- The `-N-gHASH` version suffix occurs in practice: `try.vikunja.io` reports `v2.7.0-6-ge7d7f173`.
- The code grant creates a session whose refresh token rotates on every refresh, without a grace period: the previous token gets 16002 (2.7.0) or a code-less 401 (2.3.0, 2.4.0) right after a rotation (auth.md §4.1).
- Logout ends the session: refreshing afterwards fails like a rotated token (auth.md §12).
- On 2.7.0, v2 `POST /oauth/authorize` with a wrong `response_type` returns 500 `unexpected error occurred`; 2.4.0 returns 400 `response_type must be 'code'`. This answers the `huma` question in auth.md §16.
