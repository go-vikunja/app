# Contributing to Rurana

Thank you for helping. Rurana is free software under the AGPL-3.0-or-later with an additional permission for app stores ([NOTICE.md](NOTICE.md)). Your contribution is licensed under the same terms, the additional permission included, and you keep your copyright in it.

## Issues

Open an issue for a bug, with the app version, the platform, the Vikunja server version and the steps that show it, or for an idea before you build it. Larger changes are recorded in [docs/decisions.md](docs/decisions.md), so it helps to agree on the approach first.

Report a security problem privately, through the repository's private vulnerability reporting, not in a public issue. The [threat model](docs/threat-model.md) explains what the app protects.

## Pull requests

- One topic per pull request, with tests for what changes.
- Every commit is signed off ([Developer Certificate of Origin](#developer-certificate-of-origin)).
- The checks of CI pass. The [README](README.md#common-commands) has every command; the usual ones, from the repository root:

  ```sh
  tool/check_format.sh                  # --fix formats in place
  flutter analyze
  (cd app && flutter test)
  (cd packages/vikunja_domain && flutter test)
  (cd packages/vikunja_logic && flutter test)
  (cd packages/vikunja_api && flutter test --exclude-tags contract)
  (cd plugins/rurana_widgets && flutter test)
  ```

  After a change to ARB files, annotated providers or Drift tables, regenerate and commit the generated code (`cd app && flutter gen-l10n && dart run build_runner build`). After a change to the description editor (`app/editor/`), run `tool/build_editor.sh` and commit the page it builds and its notices. After a change to the Android dependencies, write the Gradle lockfile and the Android libraries' notices again (`python3 -I tool/build_android_notices.py`, see the [README](README.md#common-commands)).
- The Android app contains no Google Play services library: it uses embedded Cronet, which the app's Gradle build puts in place of Play services Cronet ([D67](docs/decisions.md#d67-agpl-30-or-later-with-an-app-store-permission-contributions-under-the-dco-the-name-and-the-logo-reserved-no-f-droid-the-legal-notices-on-an-about-page-and-the-licence-page-the-source-code-published-before-the-first-store-release)). A dependency that brings a Play services library fails the notices check; it needs the owner's decision first.
- Accessibility: every new route, page pushed with the Navigator, and dialog, sheet, picker or menu call needs a scenario in the accessibility sweep (`app/test/a11y/`, listed in `sweep_suites.dart`) or an exemption with a written reason (`route_walk.dart` for routes, `overlay_inventory.dart` for the calls); the sweep fails otherwise. `cd app && flutter test test/a11y` runs it alone in about a minute and a half. App bar titles use `ScreenTitle`, headings name their level, and announcements go through `announce` or `Announcer`. No check of the sweep is relaxed without a reason in the test and an entry among the deviations of [D68](docs/decisions.md#d68-screen-readers-heading-levels-on-screen-titles-and-section-headers-one-announcer-with-the-apps-own-live-region-on-android-high-contrast-and-reduce-motion-followed-and-a-route-sweep-that-every-route-pushed-page-and-overlay-must-pass-wcag-22-aa-as-the-yardstick-with-written-deviations).
- Large screens: a new route's scenario also needs its class in `app/test/a11y/readable_widths.dart` (a list at 840 dp, settings or a form at 640 dp, the whole width, or a cap of its own), and the screen centres its content with `ReadableWidth` or `SliverReadableWidth` inside the scroll view, never with a box around it; iOS sheets open through `showReadableCupertinoSheet`, and date and time pickers take `pickerFormatsBuilder`. The sweep and source scans check all of it ([D69](docs/decisions.md#d69-large-screens-one-window-layout-helper-readable-widths-of-840-dp-for-lists-and-640-dp-for-settings-and-forms-with-scrolling-margins-dialogs-at-most-560-dp-and-ios-sheets-at-most-640-dp-only-on-tablet-sized-windows)).
- Task detail pane: a list inside a tab opens a task with `openTaskDetail`, which uses the pane beside the list on wide windows and the sheet elsewhere; only a page over the shell calls `showTaskDetail` directly. Its rows or cards mark the task open in the pane with `TaskDetailPaneScope.isSelected` and `SelectedTaskHighlight`, and add `selected: true` to their semantics only while selected. Such a list also gets a pane scenario in `app/test/a11y/scenarios_pane.dart` (a route scenario whose variant starts with `pane`, on the tablet in landscape only) and its class in `app/test/a11y/readable_widths.dart`. The completeness test checks that each pane scenario names a swept route, runs only on the tablet in landscape and has its class; nothing checks that a new list has a pane scenario, so add it yourself. A change to the shell or the detail keeps the back order of a pane (what is over the shell first, then the pane, then the tab's pages) for the button and the swipe, which `app/test/helpers/back_gestures.dart` drives ([D70](docs/decisions.md#d70-task-detail-pane-on-windows-at-least-840-dp-wide-and-480-dp-high-a-task-opens-beside-the-list-one-pane-per-tab-with-a-back-stack-and-a-selected-row-the-sheet-everywhere-else-back-through-the-pane-first-and-pages-in-a-tab-without-androids-predictive-back)).
- No code or text copied from Vikunja or from other projects. Read them for behaviour, then write your own. The additional permission for app stores can only cover work whose authors grant it. Third-party code needs a licence that allows app stores (such as MIT, BSD or Apache 2.0) and an entry in the notices ([NOTICE.md](NOTICE.md#third-party-material)); ask before you add a dependency.

## Translations

Add new strings to `app/lib/l10n/arb/app_en.arb` only, each with a `description` that says where it appears; a string that is only spoken, never shown, starts its description with "Screen reader: ". A new plural puts the number in the singular branch too (`=1{{count} task}`). The project maintains the German file (`app_de.arb`) and adds the German text before a release. Other languages come later through a translation platform (roadmap step 36).

## Name and logo

The name "Rurana" and the llama logo are not under the AGPL ([NOTICE.md](NOTICE.md#name-and-logo)). Their files may be passed on unmodified only as part of a copy of this repository or its history, or of an unmodified build published by Benedikt Lesch. Pull requests that change the logo files are not accepted. A fork that distributes an app built from modified source must use its own name and logo.

## Style

- Follow the code around your change, the analyzer's rules (`very_good_analysis`) and `dart format`.
- Clear names instead of comments. Comment only a reason or a constraint the code cannot show; no comments that repeat the code.
- Documentation in plain English, short sentences.

## Developer Certificate of Origin

Sign off every commit with `git commit -s`. Git then adds a line with the name and email of your Git configuration:

```text
Signed-off-by: Your Name <you@example.org>
```

The name and email must be those of the commit's author. Merge commits need it too, because a merge can bring changes of its own: merge with `git merge --signoff`, or rebase onto the target branch instead of merging it in (GitHub's "Update branch" button makes a merge without a sign-off). A check in CI fails a pull request with a commit that is not signed off. To sign off commits you have already made, run `git rebase --signoff <base>` (for example `git rebase --signoff origin/main`; it also replaces merges by rebased commits) and push with `--force-with-lease`.

With the sign-off you certify the Developer Certificate of Origin 1.1:

```text
Developer Certificate of Origin
Version 1.1

Copyright (C) 2004, 2006 The Linux Foundation and its contributors.

Everyone is permitted to copy and distribute verbatim copies of this
license document, but changing it is not allowed.


Developer's Certificate of Origin 1.1

By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I
    have the right to submit it under the open source license
    indicated in the file; or

(b) The contribution is based upon previous work that, to the best
    of my knowledge, is covered under an appropriate open source
    license and I have the right under that license to submit that
    work with modifications, whether created in whole or in part
    by me, under the same open source license (unless I am
    permitted to submit under a different license), as indicated
    in the file; or

(c) The contribution was provided directly to me by some other
    person who certified (a), (b) or (c) and I have not modified
    it.

(d) I understand and agree that this project and the contribution
    are public and that a record of the contribution (including all
    personal information I submit with it, including my sign-off) is
    maintained indefinitely and may be redistributed consistent with
    this project or the open source license(s) involved.
```

In this repository, "the open source license indicated in the file" is the AGPL-3.0-or-later with the additional permission for app stores, as [NOTICE.md](NOTICE.md) states for the whole repository.
