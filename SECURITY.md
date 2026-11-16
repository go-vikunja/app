# Security policy

## Reporting a problem

Report a security problem in the app privately, never in a public issue, a pull request or the forum:

- through GitHub's [private vulnerability reporting](https://github.com/go-vikunja/app/security/advisories/new) for this repository, or
- by email to security@vikunja.io. Vikunja's [security page](https://vikunja.io/security/) has its PGP key.

Check the problem against the latest release or `main` first. Describe what you found and how to reproduce it, with the app version, the platform and its version, and the Vikunja server version. Leave out passwords, tokens and other people's data. If an AI helped with the report, say so, check its claims on a device against a running server, and be ready to answer questions about it.

Don't test with other people's accounts or data, and keep the problem private until a release fixes it.

## Scope

This policy covers what is in this repository: the Android and iOS app with its widgets and its description editor, and the scripts and workflows that build and release it. The [threat model](docs/threat-model.md) says what the app protects and from whom.

A problem of the Vikunja server or its web interface goes to the [server's security policy](https://github.com/go-vikunja/vikunja/blob/main/SECURITY.md). That policy also lists reports that are not vulnerabilities, among them that the server's OAuth2 sign-in for the apps takes client ids that are not registered, with no client secret and no consent screen. If you are not sure which side a problem is on, report it here.
