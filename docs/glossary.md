# Glossary and style

The terms and the style of the app's texts in English and German ([D71](decisions.md#d71-complete-english-and-german-british-english-as-the-base-a-glossary-a-wording-pass-over-every-string-more-server-error-codes-in-the-apps-own-words-with-the-servers-detail-as-the-fallback-the-devices-language-followed-while-the-app-runs-names-sorted-with-accents-folded-an-app-language-row-that-opens-the-systems-page)). They apply to `app/lib/l10n/arb/app_*.arb` and to the native strings (Android `res/values*/strings.xml`; on iOS the permission texts in `ios/Runner/Info.plist` and `ios/Runner/de.lproj/InfoPlist.strings`, and the widget extension's texts, whose English is the key in its Swift sources and in `en.lproj` and `de.lproj` `Localizable.strings`, or `Localizable.stringsdict` for the plurals), and every new string follows them. Translators of a future language read the English part for the app's terms. How to add a string is in [CONTRIBUTING.md](../CONTRIBUTING.md#translations).

## Both languages

- **Kept as they are:**
  - brand and server names: Rurana, Vikunja, CalDAV, TOTP, Cloudflare Access, Gravatar, Todoist, the feature name Quick Add Magic;
  - the Quick Add syntax words and prefixes;
  - filter syntax and operators (`done = false && labels in Work`, `&&`, `||`, `not in`);
  - date-format patterns (DD/MM/YYYY);
  - the server's untranslated permission names and error details.
- The server's default names (Inbox, Favorites, My Open Tasks, List, Gantt, Table, Kanban) are translated for display only ([D45](decisions.md#d45-app-shell-on-wide-android-screens-the-colour-scheme-and-dynamic-colour-the-webs-display-settings-applied-only-when-set-translated-default-names-the-project-tree-with-favourites-saved-filters-and-archived-projects-smart-lists-a-sticky-offline-banner)).
- Placeholders keep their names. Sentences are not assembled from fragments unless the description says so (for example `assigneePickerFallback`).

## English (British; `app_en.arb` is the base)

- **Spelling:** British throughout (colour, favourite, organise/organisation, recognise, licence as a noun, -ise). ARB keys keep their spelling (`favorites*`, `*Color*`), and proper names keep theirs (GNU Affero General Public License).
- **Case:** sentence case for titles, labels, buttons, chips, menu items and headings, including text in parentheses: "Priority (highest first)", "Next week".
- **Apostrophe and quotes:** the ASCII apostrophe `'` (don't, server's). Curly double quotes “…” around quoted titles and syntax words. No ASCII `"`, and no single quotes used as quotation marks.
- **Ellipsis:** one character, with no space before it, also after a placeholder ("Loading…", "Looking for Vikunja at {address}…"). It marks work in progress, an entry that opens a further choice ("Custom…") and typing hints ("Write a comment…"). Never three dots.
- **Dashes:**
  - a spaced em dash " — " as a sentence dash;
  - an en dash for ranges: unspaced between simple items (A–Z), spaced between placeholders ({from} – {to}).
- **Settings paths:** "Settings › General › About".
- **Confirmation dialogs:** the title is a question ending in "?" ("Delete task?"), and the button is the bare verb ("Delete").
- **Field errors:** a short imperative with a full stop that starts with the action ("Enter a title.", "Choose at least one permission.").
- **Full stops:** full sentences end with one; titles, labels, buttons, chips and fragments don't. "can't" and "cannot" are both fine.
- **UI names in running text** keep their capitals from the screen, without quotes ("tap Send now", "the Account tab"). Quotes only where the name would otherwise read as part of the sentence ("Turn on “Show done”").
- **Terms:**
  - tasks and projects: task, subtask, parent task; project, subproject, parent project;
  - other objects: label; team; saved filter; view (List, Gantt, Table, Kanban);
  - boards: column (a kanban bucket, never "bucket"); board (a kanban view); card (a task on a board);
  - on a task: favourites; assignee; reminder; due date, start date, end date; done (the state; "Mark as done"); open (the state); identifier; comment; attachment;
  - sharing: link share (what an admin creates) vs shared link (what a guest opens); guest access;
  - device settings: connection settings; access headers; app lock;
  - Rurana's pages on the website: help (the support page, "Help and bug reports"), privacy policy, legal notice (the Impressum); a server's own are its privacy policy and imprint;
  - bug for a fault in Rurana that someone reports ("report a bug").
  - the bin for the server's trash (Vikunja 2.8.0 and later; the web says Trash): a task or project is moved to the bin, restored, deleted forever (also for the server's purge after 30 days; never "for good"); the bin is emptied ("Empty bin"). Code, ARB keys and the API keep "trash".
  - following for the server's subscriptions: a user follows a task or project and unfollows it ("Follow task", "Unfollow task", "Following the project …"); never subscribe or watch. On Vikunja 2.8.0 and later the tasks a user follows are the ones whose reminders reach them. Only the share cleanup notice keeps "subscriptions", for what the server deletes.
- **Sign in:** "sign in" (verb), "sign-in" (noun or adjective: sign-in page), "sign out". Never log in, login or log out.
- **Device:** "device" for the phone or tablet the app runs on. "phone" only for another phone (`linkShareQrHint`) and in the connect tagline.
- **People and places:**
  - the web (Vikunja's web app); the server; "whoever runs the server" (not administrator);
  - the Account tab, the Projects tab, Overview, Upcoming;
  - home screen on Android; Home Screen only in iOS steps.
- **Spellings:** email, username, sync/synced/syncing, Wi-Fi, OK, set up (verb) vs setup (noun), online/offline.

## German (du)

- **Address:** always du, never Sie.
  - Helper sentences use the du imperative ("Lass das Feld leer, …"); placeholders and field hints may be infinitives ("Emoji eingeben").
  - Imperatives with and without -e are both correct. New strings use the full form (Prüfe, Versuche, Wähle), and one sentence never mixes the two.
  - Field errors are a du imperative with a full stop, without "Bitte" ("Gib einen Titel ein.").
- **Quotes:** „…“ only. UI names cited in running text go in „…“ (im Tab „Konto“, tippe auf „Weiter“). Settings paths written with › stay unquoted.
- **Ellipsis:**
  - a space before "…" when it stands for missing words or marks progress ("Wird gespeichert …", "Alle …");
  - no space where it shortens a path or URL (/share/…/auth).
- **No-break spaces:** U+202F (narrow no-break space) before % and between a number and a unit or abbreviation (64 KB, 10 Min., 1 Std., {percent} %), and inside "z. B.".
- **Dashes:** a spaced en dash "–" as a sentence dash; an unspaced en dash for compact ranges (A–Z); a spaced one between dates ({from} – {to}).
- **Progress texts** use the passive with an ellipsis ("Wird gespeichert …", "Aufgaben werden geladen …", "Einladung wird geprüft …").
  - No first-person forms that read as a command ("Prüfe die Einladung …").
  - The one-word "Verbinde …" may stay.
- **Fixed phrases:**
  - "Versuch(e) es noch einmal" (or "erneut"), not "noch mal" or "nochmal";
  - "Das lässt sich nicht rückgängig machen." for "This can't be undone."
- **Verbs:**
  - erstellen for creating anything (Aufgabe, Projekt, Label, Team, Spalte, Ansicht, Link, Token, Konto), never anlegen;
  - festlegen for giving a field a value (Datum, Priorität, Titelbild, Spalte), and "Nicht festgelegt" / "Kein … festgelegt" for an unset value. setzen only in its literal sense (in Anführungszeichen setzen, zurücksetzen);
  - anzeigen for show actions, toggles, chips and hints, paired with ausblenden. A finite "zeigt" that describes what something displays may stay;
  - löschen for delete, entfernen for remove;
  - öffnen is the action, offen the state;
  - erledigt for a task's state ("Als erledigt markieren"), fertig for finishing a picker or dialog;
  - laden takes an object: "wird geladen", never an intransitive "lädt".
- **Dates:**
  - Fälligkeitsdatum is the field (edit page, new task, sort, table column, reminders);
  - "fällig am {date}" in sentences ("fällig am {date}, offener Beginn") and "Fällig am" as the detail sheet's row label;
  - the spoken due texts leave out "am": "Fällig {when}" and "Überfällig, war fällig {when}", whose {when} may be relative ("heute", "vor 2 Tagen") or a date, and the Quick Add preview's "Fällig {date}, {relative}" (`taskDueSemantics`, `taskOverdueSemantics`, `quickAddDueSemantics`);
  - Fälligkeit(en) is the generic noun ("Ohne Fälligkeit");
  - Startdatum, Enddatum.
- **Favourites:** Favoriten (the list or section), Favorit (one item), "Zu Favoriten hinzufügen", "Aus Favoriten entfernen".
- **Terms:**
  - objects: Aufgabe, Unteraufgabe, Projekt, Unterprojekt, Label/Labels (never Etikett), Team, gespeicherter Filter, Ansicht;
  - boards: Spalte (bucket), Board (kanban view), Karte;
  - Bezeichner for an identifier (not Kennung);
  - Zugriff for access and Berechtigung for permission, not Rechte;
  - accounts: Konto; anmelden/Anmeldung, abmelden; a session the server ended is "beendet", not "abgelaufen";
  - Synchronisierung;
  - Aktivitäten for the notification category and its switch;
  - Gerät for the device; Handy only for a literal phone and in the tagline;
  - Startbildschirm (Home-Bildschirm only in iOS steps);
  - 12-/24-Stunden-Format;
  - "die Person, die den Server betreut" for whoever runs the server;
  - Rurana's pages on the website: Hilfe (the support page, „Hilfe und Fehler melden“), Datenschutzerklärung, Impressum; Fehler also for a bug („einen Fehler melden“).
  - Papierkorb for the server's trash: in den Papierkorb verschieben, wiederherstellen, endgültig löschen, „Papierkorb leeren“; Rückgängig for Undo.
  - folgen for the server's subscriptions, with the dative (einer Aufgabe, einem Projekt folgen), and „nicht mehr folgen“; never abonnieren or beobachten. Only the share cleanup notice keeps „Abonnements“.
- **Compounds:** German nouns form closed compounds (Standardspalte, Standardprojekt, Spaltenlimit). A hyphen only with English words, abbreviations or participles (Projekt-Admin, Label-Titel, CalDAV-Token, Erledigt-Spalte).
- **The web's own labels** are quoted as the German web shows them („Account erstellen“).
