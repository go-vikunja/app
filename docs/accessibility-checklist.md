# Accessibility checklist

This is the manual accessibility pass of Rurana, the Android and iOS client for self-hosted Vikunja. It goes with the automated checks of step 36a ([D68]): the route sweep, the 3.12× text check and the static rules in `app/test/a11y/`. The sweep covers what a widget test can see; this pass covers what only a screen reader, a switch and real fonts on a device show. The yardstick is WCAG 2.2 AA with the deviations listed in [D68].

A sign-off goes through section 1 on the tree being signed off, section 2 on Android (TalkBack, Switch Access, Accessibility Scanner) for every area the change touched (all of it before a release), and section 3 once in the final iOS phase (VoiceOver). The results and the date go into the step's decision: per flow, what TalkBack (German and English), Switch Access and the Scanner showed, and each finding with its screen and severity, fixed or a follow-up.

**Status:** not yet run. On 2026-10-28 the pass could not be performed on the emulator ([D68]); it is open for the owner on the tablet emulator, or for the final device phase together with VoiceOver ([Q19]).

## 1. Automated

```sh
(cd app && flutter test test/a11y)    # the sweep, the 3.12× check, the completeness checks, the static rules
(cd app && flutter test)              # everything, the sweep included, as CI runs it
```

- Every route, page pushed with the Navigator and dialog, sheet, picker or menu call has a scenario or an exemption with a written reason; a new one without either fails ([CONTRIBUTING.md](../CONTRIBUTING.md#pull-requests)).
- Each scenario runs on Android and iOS, light and dark, English and German, with Flutter's tap-target, labelled-target and contrast guidelines and the project's checks for heading levels, headings that are no buttons, image labels and control names, on every scroll stop.
- The six core screens have no overflow at 3.12× on iOS, at 375 × 667 and 320 × 568 points.
- Every `header: true` has a heading level, and every announcement goes through the announcer.

## 2. Manual, on Android

### 2.1 Setup

- **Device:** the Pixel_Tablet emulator (Android 16, Google Play image). TalkBack 16 came preinstalled; Switch Access is part of the same Android Accessibility Suite. Accessibility Scanner comes from Play, which needs the owner's Google sign-in. A phone with TalkBack works as well.
- **A person at the controls.** TalkBack ignores touch and key events that `adb` injects (its focus does not move, and its Alt+arrow shortcuts sent that way do nothing), and logging its node tree needs a four-finger gesture. On the emulator, use the host keyboard with TalkBack's keyboard shortcuts; check the keymap first (TalkBack settings › Advanced › Keyboard shortcuts) and note it in the results.
- **Build:** the release APK, installed with `adb install -r`; the project's emulator rules apply (start lean, one emulator, stop it afterwards).
- **Server and data:** the local test server, seeded with `tool/seed_demo_data.py`; make sure it has: an overdue task and a task due later today; a description with headings, a link and a checklist; a Kanban view with a done column; a Gantt view with one *blocking* and one *precedes* relation between tasks in range; two accounts; an API token, a CalDAV token and a second session (signed in on the web).
- **Settings during the pass:** font size and display size at their maximum for flows 2, 5, 6 and 11 (once also at the default); dark theme for half of the flows; colour correction for deuteranomaly for flows 2 and 8; every flow in German, flows 2, 3, 5 and 8 also in English.
- **Known:** changing the system Contrast, or the wallpaper while system colours are on, makes Android relaunch the activity, and the app comes back at the Overview ([D68]). Set the contrast before opening the screen to check.

### 2.2 In every flow

- **Name, role and state** of every control, e.g. "Als erledigt markieren, Kästchen, nicht aktiviert".
- **Reading order** follows the visual order; no stop without a name ("Schaltfläche" alone), nothing read twice.
- **Headings:** with the Headings reading control, TalkBack steps through the screen's title (level 1) and its section headers (level 2).
- **Actions:** the Actions menu lists the custom actions; their result is announced or visible.
- **Dialogs and sheets** take focus, and nothing behind them is reachable. Record where focus lands after closing (Flutter does not return it to the trigger).
- **Live regions** speak: the offline banner, sync errors, form errors and the app's announcements.
- **No time limits:** a snackbar with Undo stays while TalkBack is on.
- **Switch Access** (auto-scan, two host keys as Select and Next): every action of the flow can be reached.
- **Accessibility Scanner** on each main screen of the flow: targets, contrast and labels with real rendering, platform views and widgets included.

### 2.3 Checks of step 36a

- [ ] **Headings:** for the Overview, a project's list, the task sheet, a settings page (Account › Settings) and a description with h1–h3, list the headings TalkBack's Headings control reaches: the screen title, then the section headers; in the description, its own levels.
- [ ] **A heading is no button:** on the Account tab ("Konten" above "Konto hinzufügen"), a project's share page ("Personen" above "Person hinzufügen"), a day with one task in Upcoming and the task sheet ("Unteraufgaben" above "Unteraufgabe hinzufügen"), Headings lands on the heading alone, a double tap there does nothing, and the row follows as an item of its own. By design, the account header on the Account tab and the task sheet's title are headings that are also buttons.
- [ ] **Announcements,** each spoken once and not cut off (on Android every one goes through the app's live region):
  - a board move ("Nach Doing verschoben") and a list move ("Nach oben verschoben"); one board move while TalkBack is still reading the card: is the message queued or lost?
  - right after a confirm dialog closes: deleting an API token ("Token gelöscht"), deleting a CalDAV token ("CalDAV-Token gelöscht"), ending the other sessions;
  - the same message twice in a row: copy a certificate fingerprint twice ("Kopiert" both times);
  - nothing stale after unlocking the app or after closing the task sheet;
  - form errors: a wrong password for a protected share link, the client certificate page's "Wähle zuerst eine Datei aus." and its wrong password, an empty access-header value. Each is spoken once when it appears and once more when the same input is submitted unchanged. A field with a helper text (the share-link password) may say a new error twice, a framework effect ([D68]): record whether it does.
- [ ] **Overdue:** an overdue row and card show the circled exclamation mark instead of the calendar, in the error colour, and so does the sheet's due row, which reads "Überfällig, war fällig …". Check it with an absolute date format set on the web, where the colour was the only sign before.
- [ ] **Refresh:** Sessions, API tokens and CalDAV have "Aktualisieren" in the app bar, reachable with TalkBack and Switch Access; the list reloads.
- [ ] **Gantt:** one text above the rows reads "Heute, *Datum*; Zeitraum: *von* bis *bis*" and is no button; the blocking row ends with "blockiert *Titel*", its target with "blockiert durch *Titel*"; the precedes pair with "geht *Titel* voraus" and "folgt auf *Titel*".
- [ ] **Contrast:** Settings › Accessibility › Colour and motion › Contrast at medium and at high, each with "Use system colours" (Account tab › Appearance) on and off: the app uses the high-contrast scheme (stronger outlines and text), with system colours in the wallpaper's hue. Back at standard, the normal scheme returns.
- [ ] **Remove animations** on: the board jumps to the column after a drop or a move instead of gliding; focusing the comment field jumps the task sheet to full height; "Zu heute springen" in Gantt jumps. Record any other motion that remains.
- [ ] **Dragging without TalkBack** (WCAG 2.5.7): as a pointer user, confirm that moving a card to another column, reordering cards, list rows and sibling projects has no single-pointer way, and that a column's place (its menu), a project's parent (project edit › parent) and a task's project (task edit › project) do. [D68] records exactly this.

### 2.4 The flows

Each flow lists what to do, what to expect and what to record, beyond section 2.2.

1. **Connect and sign in.** Signed out, or Account › Add account: a wrong address first, then the test server; Connect; choose the sign-in on the server overview; sign in in the browser and return. *Expect:* the address field has a name; the failure card is read when it appears; the insecure-connection question (http) takes focus; after the browser the app is in front with focus inside it; the first-sync screen speaks its progress. *Record:* where focus lands after the browser.
2. **First sync and the Overview.** Let the first sync finish; walk the Overview with swipes, then by headings. *Expect:* the sync status as a live region; the search pill, greeting, counts and section headings; each row one stop with its whole summary (title, project, due or overdue in words, priority, labels, assignees), then its checkbox and its star. *Record:* any row read in pieces.
3. **Done and Undo.** Activate a row's checkbox, find "Rückgängig" in the snackbar and activate it. *Expect:* the state change read; the snackbar stays while TalkBack is on; Undo restores the task. *Record:* where focus goes after the snackbar closes.
4. **Quick add.** "Neue Aufgabe"; type `Anna anrufen tomorrow *Arbeit +Projekt`; take a suggestion; remove a recognised part; add. *Expect:* the sheet's title is a heading; recognised parts read with their meaning; suggestions reachable; the result announced. *Record:* whether new suggestions are spoken; focus after the sheet closes.
5. **Task sheet.** Open the overdue task; walk the sheet; in the description its headings, a link and a checklist item ticked; attachments; show the comments, write one with an @mention, add a reaction. *Expect:* the title at level 1 and the sections at level 2; the due row as in 2.3; links as links; checklist items with their state; "Kommentar gesendet" announced; reaction chips with emoji, count and state. *Record:* the description's heading levels; the mention bar's announcements.
6. **Edit page.** Edit from the sheet; change the due date and time, add a reminder, labels and assignees through their pickers; save. *Expect:* the title is a heading; "Speichern" stays in the app bar at the largest font (capped at 2×); pickers take focus and report their result; "Gespeichert" announced. *Record:* focus after each picker; any field without a name.
7. **Project list and tree.** In a manually sorted list, Actions › "Nach oben verschieben" on a row; in Projects, "In *Projekt* verschieben" and "Aus *Projekt* herausnehmen". *Expect:* distinct action names; each move announced. *Record:* whether focus follows the moved row.
8. **Kanban.** On a card, "Nach Doing verschieben", then into the done column and out again; on a column header, "Nach rechts verschieben"; with Remove animations off and on. *Expect:* the card is one stop (title, details, column); numbered names when column titles repeat; each move announced; the board shows the moved card or column. *Record:* a move while TalkBack speaks; the column header's "Voll" and done hints.
9. **Upcoming.** Pick a day in the day strip; open the range sheet; pick a preset and a custom range. *Expect:* days with weekday, date and their selected state; the range button reads its name and dates; the sheet takes focus; the list updates. *Record:* how the day groups are read.
10. **Search.** Open search, type a query, walk the results. *Expect:* the field reads "Suchen" and its hint; results grouped by kind, each one stop. *Record:* whether the result count or "no results" is spoken.
11. **Gantt and Table.** Read the summary above the rows; walk the rows across the range, bars off screen included; expand and collapse a parent; "Zu heute springen"; then the Table view. *Expect:* as in 2.3; dates in words, "geschätzt" for estimated bars, the relations; focus on a bar off screen scrolls the chart sideways; table rows read the chosen columns. *Record:* any bar TalkBack cannot reach.
12. **Description editor.** "Beschreibung bearbeiten" from the sheet; move TalkBack into the editor, type, use the toolbar (bold, list, checklist), type `@` for the mention bar, go back to the native page, save. *Expect:* TalkBack enters the WebView and reads the editable area in the app's language; toolbar buttons with their names and toggled state; mention suggestions announced; leaving the WebView reaches the toolbar or the app bar. *Record:* **yes or no: does TalkBack enter the WebView**, and how; any focus trap. If it does not, a plain-text description field for screen-reader users becomes a follow-up.
13. **App lock.** Account › Privatsphäre › App-Sperre on (with a device PIN); leave the app past the timeout; return; unlock. *Expect:* the lock screen names itself ("Rurana ist gesperrt"), "Entsperren" has focus, nothing behind is reachable; after the unlock focus is in the app and nothing stale is spoken. *Record:* whether the privacy cover is silent in the app switcher.
14. **Account switcher and sign-out.** Account tab › the accounts row; switch to the second account; open "Abmelden", cancel, open it again. *Expect:* the sheet takes focus; accounts read with name and host, the active one marked; "Zu *Name* gewechselt" announced; the dialog takes focus with its title and text. *Record:* focus after the sheet and the dialog close.
15. **Home-screen widgets.** Add the Tasks and the Quick add widget; read a row, activate its Done checkbox and "Neue Aufgabe"; check the smallest size at the largest font. *Expect:* each row one stop; the Done checkbox named after the task; the count read; nothing clipped. *Record:* the Scanner on the home screen.

## 3. Final iOS phase

Once, on a device (the simulator for what it can show):

1. **VoiceOver:** the rotor's Headings on the screens of 2.3; the editor WebView's content; the announcements of 2.3, which on iOS go through the platform.
2. **Largest text:** at AX5 (Settings › Accessibility › Display & Text Size › Larger Text, largest) with Bold Text on: the six core screens with the system font; the picker sheet (task edit › due date; API token › custom expiry, which has a title) shows its title on a line of its own and Cancel and Done side by side or stacked, nothing cut off; the day-range sheet (Upcoming's range button, a Gantt view's range controls) shows Cancel and Done and both From/To segments in full. Record whether the Gantt bars' titles follow Bold Text.
3. **Increase Contrast:** the app uses the high-contrast scheme; the alerts' actions (delete task, sign out, the http question) with and without it, the 1.4.3 deviation of [D68].
4. **Reduce Motion:** the board, the task sheet and "Go to today" jump; page and sheet transitions still slide, as [D68] records.
5. **The tab bar:** inactive labels readable in light and dark.

[D68]: decisions.md#d68-screen-readers-heading-levels-on-screen-titles-and-section-headers-one-announcer-with-the-apps-own-live-region-on-android-high-contrast-and-reduce-motion-followed-and-a-route-sweep-that-every-route-pushed-page-and-overlay-must-pass-wcag-22-aa-as-the-yardstick-with-written-deviations
[Q19]: open-questions.md#q19-device-setup-for-the-manual-talkback-pass
