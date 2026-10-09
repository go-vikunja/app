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

## Confirmed on live servers

These statements in the research files are now confirmed:
- `/api/v1/info` and `/api/v2/info` return the same body; v2 adds `$schema`.
- `/api/v1/info` already answers on 1.0.0, with the same shape minus the 2.4.0 additions.
- `enabled_pro_features` and `allow_icon_changes` also appear first in 2.4.0; they are absent in 2.3.0.
- `registration_enabled` lives under `auth.local`, not at the top level.
- The `-N-gHASH` version suffix occurs in practice: `try.vikunja.io` reports `v2.7.0-6-ge7d7f173`.
