# Vikunja OAuth 2.0 Integration for Flutter

## Endpoints

| Endpoint | Method | Auth | Purpose |
|---|---|---|---|
| `/oauth/authorize` | Browser navigation | None (frontend route) | User-facing authorize page |
| `/api/v1/oauth/authorize` | POST | JWT Bearer | Creates authorization code |
| `/api/v1/oauth/token` | POST | None | Exchanges code for tokens / refreshes tokens |

## Constraints

- **PKCE:** Mandatory, S256 only
- **Redirect URI scheme:** Must start with `vikunja-` (e.g. `vikunja-flutter://callback`)
- **Client ID:** Any string, no registration needed. Must match between authorize and token exchange.
- **Request/response format:** JSON only, no form encoding
- **Code expiry:** 10 minutes, single-use
- **Access token TTL:** Configured server-side (`service.jwtttlshort`, default 600s)

## Flow

### 1. Open browser to authorize

Navigate a browser/webview to:

```
https://<host>/oauth/authorize?response_type=code&client_id=vikunja-flutter&redirect_uri=vikunja-flutter://callback&code_challenge=<challenge>&code_challenge_method=S256&state=<random>
```

This is a **frontend route**, not an API endpoint. The frontend handles login (if needed) and calls the API internally. After authorization, the browser redirects to:

```
vikunja-flutter://callback?code=<code>&state=<state>
```

### 2. Exchange code for tokens

```
POST /api/v1/oauth/token
Content-Type: application/json

{
  "grant_type": "authorization_code",
  "code": "<code from callback>",
  "client_id": "vikunja-flutter",
  "redirect_uri": "vikunja-flutter://callback",
  "code_verifier": "<original verifier>"
}
```

Response:

```json
{
  "access_token": "<JWT>",
  "token_type": "bearer",
  "expires_in": 600,
  "refresh_token": "<token>"
}
```

### 3. Refresh tokens

```
POST /api/v1/oauth/token
Content-Type: application/json

{
  "grant_type": "refresh_token",
  "refresh_token": "<current refresh token>"
}
```

Same response shape. Refresh tokens are rotated on every use -- the old one is immediately invalidated.

## Error codes

All errors return HTTP 400 with `code` and `message` fields:

| Code | Meaning |
|---|---|
| 17001 | `client_id` mismatch at token exchange |
| 17002 | `redirect_uri` rejected or mismatched |
| 17003 | Missing `code_challenge` or wrong method (must be S256) |
| 17004 | Code invalid or already used |
| 17005 | Code expired (>10 min) |
| 17006 | `code_verifier` doesn't match challenge |
| 17007 | Unsupported `grant_type` |

## Notes

- The authorize page at `/oauth/authorize` is a Vue SPA route. If the user isn't logged in, the frontend's router guard redirects to `/login` and returns to the authorize page after login with all query params preserved.
- There is no consent screen -- authorization is automatic once the user is authenticated.
- The `state` parameter is passed through but not validated server-side. Validate it in the app.
