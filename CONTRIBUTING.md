# Contributing to the Vikunja app

This repository holds Vikunja's official app for Android and iOS, maintained within the Vikunja project. The app follows [Vikunja's contribution rules](https://github.com/go-vikunja/vikunja/blob/main/CONTRIBUTING.md); this file says how they apply here and adds the app's own rules.

## Questions, bugs and features

- Ask questions in the [forum](https://community.vikunja.io) or on [Matrix](https://matrix.to/#/#vikunja:matrix.org).
- Report a bug with the [bug form](https://github.com/go-vikunja/app/issues/new/choose): the app version, the platform and its version, the Vikunja server version, the steps that show the bug, what you expected and what happened. Report only a bug you have reproduced. A bug of the server or the web interface goes to [go-vikunja/vikunja](https://github.com/go-vikunja/vikunja/issues).
- Propose a feature with the feature form first, and wait until a maintainer agrees before you open a pull request. A pull request for a feature without an agreed issue may be closed. Larger changes are recorded in [docs/decisions.md](docs/decisions.md).
- Keep issues, pull requests and comments short. Never put a password, a token or another secret into them.

## Security

Report a security problem privately, never in a public issue: [SECURITY.md](SECURITY.md) says how. The [threat model](docs/threat-model.md) explains what the app protects.

## AI-assisted contributions

AI tools are allowed. If an AI wrote a meaningful part of your change, say so in the pull request's description. You are its author all the same: you understand every line, you have reviewed and tested the change, and you answer the review questions yourself.

## Pull requests

- Fork the repository, branch from `main` and open the pull request against `main` of [go-vikunja/app](https://github.com/go-vikunja/app). Pull requests on mirrors are not accepted.
- Keep a pull request small: one topic, no unrelated changes, and tests for what changes.
- Allow edits by maintainers, so that a maintainer can add a small fix or the German of a native text ([Translations](#translations)).
- Write the commit messages and the pull request's title as [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `perf:` or `chore:`, then what changes.
- The description says what changes and why. A UI change shows screenshots after the change. Each issue the pull request closes gets a line of its own, `Fixes #N`. The [template](.github/PULL_REQUEST_TEMPLATE.md) asks for these.
- The checks pass ([Setup and checks](#setup-and-checks)). The workflows of a pull request from outside the project wait until a maintainer approves them.
- A pull request whose review questions stay unanswered for two weeks may be closed. Answer, and it can be reopened.

## Setup and checks

Set up Flutter 3.47.9 and the other [prerequisites](README.md#prerequisites), then run `flutter pub get` at the repository root. The [README](README.md#common-commands) has every command.

A pull request runs `.github/workflows/ci.yaml` on GitHub Actions ([D86](docs/decisions.md#d86-ci-and-releases-on-github-actions)): the checks `checks`, `editor`, `contract`, `android`, `osv` and `ios` must pass. Each runs a script of `tool/ci/` that runs the same way on your machine (`tool/ci/checks.sh`, `tool/ci/test.sh` and so on). The usual ones, from the repository root:

```sh
tool/check_format.sh                  # --fix formats in place
flutter analyze
(cd app && flutter test)
(cd packages/vikunja_domain && flutter test)
(cd packages/vikunja_logic && flutter test)
(cd packages/vikunja_api && flutter test --exclude-tags contract)
(cd plugins/vikunja_widgets && flutter test)
```

- After a change to annotated providers or Drift tables, regenerate and commit the generated code (`cd app && dart run build_runner build`). After an ARB change or a pull, run `flutter pub get` at the root; the l10n code it writes is not committed.
- After a change to the description editor (`app/editor/`), run `tool/build_editor.sh` and commit the page it builds and its notices.
- After a change to the Android dependencies, write the Gradle lockfile and the Android libraries' notices again (`python3 -I tool/build_android_notices.py`, see the [README](README.md#common-commands)).
- After a change to the store texts (`fastlane/metadata/`), run `python3 -I tool/check_store_metadata.py`; the `checks` job runs it through its tests.

## Rules for the code

- The Android app contains no Google Play services library: it uses embedded Cronet, which the app's Gradle build puts in place of Play services Cronet ([D5](docs/decisions.md#d5-dio-with-native_dio_adapter-and-embedded-cronet)). Cronet then works on every device without Play, the app holds no proprietary code, and F-Droid stays possible. A dependency that brings a Play services library fails the notices check; it needs the maintainers' decision first.
- Accessibility: every new route, page pushed with the Navigator, and dialog, sheet, picker or menu call needs a scenario in the accessibility sweep (`app/test/a11y/`, listed in `sweep_suites.dart`) or an exemption with a written reason (`route_walk.dart` for routes, `overlay_inventory.dart` for the calls); the sweep fails otherwise. `cd app && flutter test test/a11y` runs it alone in about a minute and a half. App bar titles use `ScreenTitle`, headings name their level, and announcements go through `announce` or `Announcer`. No check of the sweep is relaxed without a reason in the test and an entry among the deviations of [D68](docs/decisions.md#d68-screen-readers-headings-one-announcer-high-contrast-reduce-motion-route-sweep).
- Large screens: a new route's scenario also needs its class in `app/test/a11y/readable_widths.dart` (a list at 840 dp, settings or a form at 640 dp, the whole width, or a cap of its own), and the screen centres its content with `ReadableWidth` or `SliverReadableWidth` inside the scroll view, never with a box around it; iOS sheets open through `showReadableCupertinoSheet`, and date and time pickers take `pickerFormatsBuilder`. The sweep and source scans check all of it ([D69](docs/decisions.md#d69-large-screens-a-window-layout-helper-readable-widths-capped-dialogs-and-sheets)).
- Link-share guests may do what the Vikunja web interface offers a link share of the same permission and the server accepts, presented the app's way, but nothing the web reaches only by a typed address ([D62](docs/decisions.md#d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind)). A new route is closed to guests unless it is added to `AppRoutes.openToGuests` in `app/lib/app/router/app_router.dart`. Either way it goes on one of the two lists that `app/test/app/guest_gates_test.dart` checks, a closed route with the reason a guest is kept from it; the test fails otherwise. A new action that uses what needs a decision for guests (a provider, or under `features/` an account's raw client or a repository call, on the watch lists in `app/test/app/guest_action_inventory.dart`) is hidden or disabled for a guest where it is offered when that rule keeps guests from it (`activeAccountIsGuestProvider`, `accountIsGuestProvider`), and the declaration that uses it gets an entry in `guestActionInventory`: `Gated` with how, `BehindClosedRoutes` with the routes that reach it, or `Open` with the reason guests may use it, and with the names it uses in `uses`; a listed declaration that starts using another name takes it into its `uses` once that name is decided for it. `guest_action_inventory_test.dart` fails otherwise and names the declaration. A new provider or repository call that needs such a decision goes onto the watch list.
- Task detail pane: a list inside a tab opens a task with `openTaskDetail`, which uses the pane beside the list on wide windows and the sheet elsewhere; only a page over the shell calls `showTaskDetail` directly. Its rows or cards mark the task open in the pane with `TaskDetailPaneScope.isSelected` and `SelectedTaskHighlight`, and add `selected: true` to their semantics only while selected. Such a list also gets a pane scenario in `app/test/a11y/scenarios_pane.dart` (a route scenario whose variant starts with `pane`, on the tablet in landscape only) and its class in `app/test/a11y/readable_widths.dart`. The completeness test checks that each pane scenario names a swept route, runs only on the tablet in landscape and has its class; nothing checks that a new list has a pane scenario, so add it yourself. A change to the shell or the detail keeps the back order of a pane (what is over the shell first, then the pane, then the tab's pages) for the button and the swipe, which `app/test/helpers/back_gestures.dart` drives ([D70](docs/decisions.md#d70-task-detail-pane-beside-the-list-on-two-pane-windows-the-sheet-elsewhere)).
- Project tree column: from about 1,120 dp of content beside the rail (`WindowLayout.threePane`) the Projects tab shows the project tree in a column before the tab's pages; a screen inside the Projects tab reads `ProjectTreeColumnScope.shownOf` for what depends on it (no back arrow in its app bar), and the route stays the source of what is open. The tree's rows mark the open list with `selected:`, as a pane's rows do, and the sweep measures the Projects tab's bands from the column's divider ([D82](docs/decisions.md#d82-projects-listdetail-the-project-tree-beside-the-project-on-wide-windows)).
- No code or text copied from Vikunja or from other projects. Read them for behaviour, then write your own: Vikunja's server and web interface are under the AGPL-3.0-or-later, which the MIT-licensed app cannot take in. Third-party code needs a licence that fits the MIT License (such as MIT, BSD or Apache 2.0) and an entry in the notices ([NOTICE.md](NOTICE.md#third-party-material)); ask in an issue before you add a dependency.

## Translations

English is the source, and every other language, German included, comes only through Vikunja's [Crowdin project](https://crowdin.com/project/vikunja), never as a pull request ([D88](docs/decisions.md#d88-translations-through-vikunjas-crowdin-project)). A pull request changes the English in `app/lib/l10n/arb/app_en.arb` and leaves the other ARB files alone. Crowdin's GitHub integration opens pull requests with the translations that Crowdin's proofreaders approved, and a maintainer merges them. German may therefore lag English for a while; a release needs it complete ([docs/releasing.md](docs/releasing.md#the-translations)).

- English is US English, like the Vikunja web, and the template: `app_en.arb` holds the texts and their descriptions; ARB keys keep the spelling they have. English follows the [glossary](docs/glossary.md) for its terms, spelling, quotes, ellipses and dashes and for how a text names the app. `app/test/l10n/us_english_test.dart` fails on a British spelling.
- Every new or changed message gets a `description` that says where it appears and what each placeholder holds: on Crowdin it is the translators' only context. A string that is only spoken, never shown, starts its description with "Screen reader: ".
- Placeholders: declare each one under the message's `placeholders`. A plural uses `one{…}`, never `=1{…}`, and shows the number there too (`one{{count} task}`), since some languages use the one form for 21 or 31 as well and translators copy the English; wording that fits only exactly 1, like "Every day", is a message of its own that the code picks for 1. `app/test/l10n/plural_forms_test.dart` checks the English. Add a key once, and leave the other entries and their order as they are.
- The translations are checked like code: `app/test/l10n/arb_parity_test.dart` lets a translation lack messages, which then show in English, but fails on a key English does not have, an empty text, invalid ICU or other placeholders than the English; `app/test/l10n/german_texts_test.dart` checks German terms. A Crowdin pull request that fails them is fixed on Crowdin, since the next one would bring the old text back.
- The native texts stay outside Crowdin for now and in English and German only: the Android widgets' (`app/android/app/src/main/res/values*/strings.xml`) and those of iOS. A change there goes into both languages in the pull request, and a maintainer adds the German through maintainer edits if you do not. On iOS the permission texts are in `app/ios/Runner/Info.plist` (English) and `app/ios/Runner/de.lproj/InfoPlist.strings`; the widget extension's English text is the key in its Swift sources (`app/ios/VikunjaWidgets/*.swift`) and in `en.lproj` and `de.lproj` `Localizable.strings`, or, for a count, `Localizable.stringsdict` with its plural forms, so changing it means changing all three.

### Adding a language

A maintainer adds a language in one pull request once `python3 -I tool/l10n_progress.py` shows its ARB file at 50 % or more, the share at which Vikunja's web ships a language too (Crowdin exports only approved translations, so the share counts approved ones):

- its `Locale` in `shippedLocales` in `app/lib/app/l10n/shipped_locales.dart` (English stays first);
- its BCP 47 tag in `app/android/app/src/main/res/xml/locales_config.xml`, in `CFBundleLocalizations` in `app/ios/Runner/Info.plist` and in `LANGUAGES` in `app/android/app/src/main/kotlin/io/vikunja/app/PreviousApp.kt`;
- a picker class for its language in `app/lib/app/l10n/picker_localizations.dart`, like `_GermanPickerLocalizations`, in the delegate's `_languages`.

`app/test/l10n/shipped_locales_test.dart` and `app/test/features/tasks/picker_formats_test.dart` name what is missing. An ARB file not on the list compiles but is never shown. Not shipped for now, though translated on Crowdin and exported like any language: right-to-left languages (Arabic, Persian, Hebrew) until the app has had a right-to-left pass, Esperanto, which Material has no texts for, and Vikunja's Swiss German, exported as `app_gsw.arb`. A new language shows the native texts in English.

## Style

- Follow the code around your change, the analyzer's rules (`very_good_analysis`) and `dart format`.
- Clear names instead of comments. Comment only a reason or a constraint the code cannot show; no comments that repeat the code.
- Documentation in plain English, short sentences.

## Licence

The app is free software under the MIT License ([LICENSE](LICENSE)). Your contribution is licensed under the same licence, and you keep your copyright in it. There is no contributor agreement and no sign-off.

The name "Vikunja" and the Vikunja logo belong to the Vikunja project and are not licensed under the MIT License. The app's icons derive from Vikunja's logo and are used with the project's permission. A fork that distributes its own build uses its own name and logo ([NOTICE.md](NOTICE.md#name-and-logo)). NOTICE.md also lists the third-party material, among it the test files with vectors from Vikunja's own tests, which stay under the AGPL-3.0-or-later and never ship.
