# TLS test servers (compose profile `tls`)

A second Vikunja 2.7.0 behind Caddy, for checking the connection settings per server (pinned certificate, CA certificate, client certificate, access headers) against a real server. Everything is a local dummy: the ports listen on 127.0.0.1 only, the data lives in a tmpfs, and the certificates, the PKCS#12 password and the access-header values are generated throwaways in `generated/` (gitignored).

| Port | What answers | Credential |
|---|---|---|
| 34528 | Self-signed leaf, no CA. Also the server's `frontend_url`, so the browser sign-in goes here | Pin (the fingerprint `tool/gen_tls_test_certs.sh` prints) |
| 34529 | Server certificate from the test CA; Caddy requires a client certificate from the test client CA | `client.p12`, plus `ca.pem` or a pin for the server certificate |
| 34530 | Server certificate from the test CA; without both access headers a 302 to a Cloudflare-Access-like login on another host | `CF-Access-Client-Id` and `CF-Access-Client-Secret` from `access.env`, plus `ca.pem` |
| 34531 | Plain HTTP straight to Vikunja, for seeding from the host. The app does not use it | none |

The profile is opt-in: CI, a plain `up -d` and `tool/contract_tests.sh` never start it. Use `docker-compose` with the same arguments if `docker compose` is missing.

## Start, seed, stop

```sh
tool/gen_tls_test_certs.sh                     # once: writes generated/, prints the self-signed fingerprint
docker compose -f test_servers/docker-compose.yaml --profile tls up -d tls-proxy   # starts vikunja-2-7-tls too
tool/wait_for_test_servers.sh --tls            # waits for 34528-34531 and checks that every gate refuses without its credential
tool/seed_e2e_user.sh http://localhost:34531   # the E2E user of test_servers/seed/e2e-user.env
python3 -I tool/tls_e2e.py seed                # project, task and a read link share (--write for a write share); prints ids only
```

Stop only the TLS pair; a plain `--profile tls down` also removes `vikunja-2-7` on 34527 and its data:

```sh
docker compose -f test_servers/docker-compose.yaml --profile tls down tls-proxy vikunja-2-7-tls
```

Inspect the compose file with `config --services` only. A plain `config` prints the access-header values from `access.env`.

## Generated files

`tool/gen_tls_test_certs.sh` writes, all EC P-256, leaves with SAN `DNS:localhost, IP:127.0.0.1`, everything valid for 397 days:

- `selfsigned.pem/.key`: the 34528 leaf.
- `ca.pem/.key`, `server.pem/.key`: the test CA and the 34529/34530 leaf.
- `client-ca.pem/.key`, `client.pem/.key`, `client.p12` (AES-256, PBKDF2), `client-legacy.p12` (3DES/RC2): what 34529 accepts.
- `wrong-client.p12` (and its PEM files): a client certificate from another CA, which 34529 refuses.
- `client-p12-password.txt`: the PKCS#12 password (no trailing newline). Caddy never loads it.
- `access.env`: only the two access-header values, loaded into the proxy's environment.
- `manifest.json`: subject, issuer, SHA-256 and validity of each certificate.

After a full regeneration while the proxy runs, run the `up -d tls-proxy` line again: it recreates the proxy, which reads `access.env` only when its container is created (a `restart` keeps the old header values).

For the pin-mismatch check, replace only the self-signed leaf and restart the proxy; the CA, the client certificate and anything installed on a device stay valid:

```sh
tool/gen_tls_test_certs.sh --renew-selfsigned
docker compose -f test_servers/docker-compose.yaml --profile tls restart tls-proxy
```

The committed unit-test fixtures in `app/test/fixtures/tls/` are a separate set (`tool/gen_tls_test_certs.sh --fixtures`).

## On the Android emulator

```sh
python3 -I tool/tls_e2e.py reverse             # adb reverse for 34528-34530 (emulator-5554, or ANDROID_SERIAL)
adb -s emulator-5554 push test_servers/tls/generated/client.p12 /sdcard/Download/rurana-test-client.p12
python3 -I tool/tls_e2e.py send-share 34528    # opens the link share in the app as a guest; the URL is never printed
```

The emulator shares the host clipboard. To paste a secret without printing it:

```sh
tr -d '\n' <test_servers/tls/generated/client-p12-password.txt | pbcopy
sed -n 's/^RURANA_TEST_ACCESS_ID=//p' test_servers/tls/generated/access.env | tr -d '\n' | pbcopy
sed -n 's/^RURANA_TEST_ACCESS_SECRET=//p' test_servers/tls/generated/access.env | tr -d '\n' | pbcopy
```

The app connects to `https://localhost:3452x`, so SNI is `localhost`. dart:io (pinned, CA-trusted and client-certificate profiles) ignores Android's user CAs. For the header-only path through the platform adapter, install `ca.pem` as a user CA (Settings › Security › Encryption & credentials › Install a certificate › CA certificate; Android asks for a screen lock, check how that interacts with the app lock). Do not install it for 34528: the self-signed leaf is not signed by it.

## Matrix

| Port | Without a profile | Steps | Expected |
|---|---|---|---|
| 34528 | Certificate rejected; "View certificate" shows the fingerprint the script printed | Trust it, then `send-share 34528` | Guest works. After `--renew-selfsigned` and a proxy restart: "certificate changed" review. Realtime only with a user account (guests have no socket) or in the Docker test |
| 34529 | Without a user CA: a server-certificate rejection first (the test CA is unknown) | Trust `ca.pem` or pin, then "Add client certificate" with `client.p12` | Guest works. With `ca.pem` as a user CA, record the platform's client-certificate error and check that "Add client certificate" appears |
| 34530 | Behind a login proxy | Access headers (user CA installed) | Guest works, realtime on polling; headers plus in-app CA trust: realtime connects. A wrong secret: behind a login proxy again |
| 34527 | The unencrypted-connection question | Allow it | Consent recorded; revoking it blocks requests |

Browser sign-in for user accounts (on 34528, the `frontend_url`) needs the password typed, so only the owner runs it.

With the profile up, the opt-in Docker tests run with `cd app && RURANA_TLS_DOCKER=1 flutter test --tags tls-docker`.

What the gates send, seen with curl against Caddy 2.11.7: a client without a certificate gets the TLS 1.3 alert `certificate_required`, one with a certificate from another CA gets `unknown_ca`. Both arrive after the client's side of the handshake has finished, on the first read.
