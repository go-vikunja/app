# Open questions

The project owner answered Q1–Q15 on 2026-10-09. This page records each answer and where it was turned into a decision. The questions themselves are condensed from [research/synthesis.md](research/synthesis.md) §5.

**Still deferred:** [Q3](#q3-licence-and-distribution) licence, [Q11](#q11-optional-near-real-time-push-on-android) push, [Q12](#q12-crash-reporting) crash reporting, [Q14](#q14-licensed-features) licensed features.

**Derived lead decision:** browser OAuth + PKCE is the only sign-in method (Q4), and it exists only on Vikunja 2.3.0 and newer. The effective support floor is therefore **2.3.0**, not the 2.0.0 of option A in Q1, and the `standard` tier for 2.0–2.2 is dropped ([D13](decisions.md#d13-support-floor-230)).

## Q1: Minimum server version

- **Asked:** floor 2.0.0 (A), or also 0.24–1.x (B)?
- **Answer:** A. The app is meant to be released some day, and older servers are very rare.
- **Result:** floor 2.3.0 because of Q4 (see the lead decision above); step 38 is removed. [D13](decisions.md#d13-support-floor-230), superseding [D7](decisions.md#d7-support-floor-200).

## Q2: App identity

- **Asked:** app name and logo, `applicationId` and bundle id, OAuth `client_id` and redirect scheme, App Group and keychain group.
- **Answer:** `applicationId` and bundle id `dev.coderoftime.vikunja`. Generate a name and a logo that lean on Vikunja's.
- **Result:** [D15](decisions.md#d15-app-id-devcoderoftimevikunja), superseding [D10](decisions.md#d10-placeholder-application-ids). Proposed name Taskuna, store listing `Taskuna – client for Vikunja` (de: `Taskuna – Client für Vikunja`), check-llama icon; pending owner approval in the step 1 review. See [branding/README.md](../branding/README.md). The OAuth `client_id` and the `vikunja-…` redirect scheme are fixed in step 3; the App Group and keychain group derive from the app id in step 19.

## Q3: Licence and distribution

**Deferred** ("leave it for now"). There is no `LICENSE` file yet.

- **Still open:**
  - Licence: porting the web frontend's logic and strings (quick-add parser, i18n, error texts, TipTap configuration) probably makes the app a derivative of AGPL-3.0-or-later code. This is not legal advice; verify it.
  - Stores: Play, App Store, F-Droid. F-Droid affects the Cronet and SQLite build choices.
- **Needed by:** step 37 at the latest. Earlier is better, because the amount of ported web code grows from step 9 onwards (quick-add in step 13, TipTap in step 25).

## Q4: Login methods

- **Asked:** browser OAuth + PKCE in step 3, then password + TOTP and API tokens in step 4?
- **Answer:** browser OAuth only, for now. Username and password login will be removed from Vikunja at some point.
- **Result:** no password + TOTP form and no API-token login; step 4 becomes multi-account. [D14](decisions.md#d14-browser-sign-in-only).

## Q5: Session lifetime

- **Asked:** how to live with OAuth sessions that expire after 72 h without a refresh.
- **Answer:** the background sync keeps the session alive.
- **Result:** background runs refresh every account's session (step 16). [D22](decisions.md#d22-session-keep-alive-through-background-sync).

## Q6: Multi-account

- **Asked:** account switcher in the first release, or later?
- **Answer:** in the first release.
- **Result:** roadmap step 4 adds, switches and removes accounts. [D16](decisions.md#d16-multi-account-in-the-first-release).

## Q7: Notification policy defaults

- **Asked:** which tasks get reminders, when due-date notifications fire, overdue digest, when to ask for Android exact alarms.
- **Answer:**
  - Reminders only for tasks where the user is the creator or an assignee.
  - Due-date notification at the exact due time, using exact alarms.
  - Ask for exact alarms during onboarding.
  - No overdue digest for now.
- **Result:** step 15. [D17](decisions.md#d17-notification-policy).

## Q8: Description editing

- **Asked:** TipTap in a WebView, Markdown-only editing, or plain text?
- **Answer:** TipTap in a WebView, for now.
- **Result:** step 25. [D18](decisions.md#d18-tiptap-description-editor-in-a-webview).

## Q9: Quick-add quirks

- **Asked:** replicate the web exactly, or fix obvious bugs?
- **Answer:** as recommended: fix the four known bugs, document the fixes, keep the grammar.
- **Result:** step 13. [D19](decisions.md#d19-quick-add-quirk-policy).

## Q10: Desktop-centric features

- **Asked:** confirm the mobile adaptations of desktop features.
- **Answer:** confirmed, except that the MCP information page and the admin panel are dropped entirely.
  - Confirmed: Gantt as a read-only timeline, table as a detailed list, keyboard shortcuts on iPad only, widgets and app shortcuts instead of the desktop quick-entry window, no seasonal logo or PWA banners.
- **Result:** steps 13, 18, 19, 29, 33 and 36. [D20](decisions.md#d20-scope-cuts-and-desktop-adaptations).

## Q11: Optional near-real-time push on Android

**Deferred** ("leave it for now").

- **Idea:** a Vikunja webhook → self-hosted ntfy → UnifiedPush. Android only; it needs per-project webhooks, and LAN targets need `webhooks.allownonroutableips`.
- **Result:** not on the roadmap. [D20](decisions.md#d20-scope-cuts-and-desktop-adaptations).

## Q12: Crash reporting

**Deferred** ("leave for now").

- **Result:** no crash reporting SDK. If it comes back, the alternative was opt-in self-hosted Sentry or GlitchTip. [D20](decisions.md#d20-scope-cuts-and-desktop-adaptations).

## Q13: Launch languages

- **Asked:** English and German first, or all 32 web locales from step 36?
- **Answer:** English and German for the beginning.
- **Result:** step 36 no longer imports the web locales. [D21](decisions.md#d21-languages-english-and-german).

## Q14: Licensed features

**Deferred.** The owner has no Vikunja licence yet and is working on getting one.

- **Result:** time tracking (step 34) is deferred until a licence is available; the admin panel is dropped anyway (Q10). [D20](decisions.md#d20-scope-cuts-and-desktop-adaptations).

## Q15: iOS toolchain on the development Mac (local setup action)

- **Asked:** run `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`, because the Dart native-asset build hooks ignore `DEVELOPER_DIR`.
- **Answer:** done. `xcode-select -p` prints the Xcode path, and local iOS builds work. CI was never affected.
