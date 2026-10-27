# Dummy TLS fixtures (test only)

**Dummy, test only, never trusted anywhere.** These certificates, keys and
values exist only for the app's unit tests, which trust them inside a single
test run on 127.0.0.1. Never install them on a device or trust them in a real
client. The CA keys are not committed.

Regenerate the whole set with:

```sh
tool/gen_tls_test_certs.sh --fixtures
```

`fixtures_expiry_test.dart` fails 60 days before the CA-chained leaves expire.
The server leaf is valid for 820 days because macOS applies Apple's 825-day
limit to CA-chained server certificates, also with custom anchors.

PKCS#12 password (a dummy, also in `client-p12-password.txt`): `dummy-fixture-password`

| File | What it is | notAfter |
|---|---|---|
| `selfsigned.pem`, `selfsigned.key` | Self-signed server leaf, no CA: only a pin trusts it. EC P-256, SAN `DNS:localhost, IP:127.0.0.1`, EKU serverAuth | 2046-10-22T11:00:02Z |
| `ca.pem` | Test server CA | 2046-10-22T11:00:02Z |
| `server.pem`, `server.key` | Server leaf signed by `ca.pem`, SAN `DNS:localhost, IP:127.0.0.1`, EKU serverAuth | 2029-01-24T11:00:03Z |
| `client-ca.pem` | Test client CA (what an mTLS server trusts and advertises) | 2046-10-22T11:00:03Z |
| `client.pem`, `client.key` | Client leaf signed by `client-ca.pem`, EKU clientAuth | 2046-10-22T11:00:03Z |
| `client.p12` | `client.pem` + key + `client-ca.pem`, AES-256-CBC, PBKDF2, SHA-256 MAC | 2046-10-22T11:00:03Z |
| `client-legacy.p12` | The same in the legacy format (3DES/RC2, SHA-1 MAC) | 2046-10-22T11:00:03Z |
| `wrong-client.p12` | A client leaf from another CA, same password: an mTLS server trusting `client-ca.pem` refuses it | 2046-10-22T11:00:03Z |
| `client-p12-password.txt` | The dummy PKCS#12 password, no trailing newline | |
| `access.env` | Dummy Cloudflare Access id and secret (`RURANA_TEST_ACCESS_ID`, `RURANA_TEST_ACCESS_SECRET`) | |
| `manifest.json` | Subject and issuer (as dart:io's `X509Certificate` prints them), SHA-256 of the DER (upper-case hex) and validity of each certificate | |
