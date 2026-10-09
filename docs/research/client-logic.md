# Vikunja web client logic to port to Flutter (area: client-logic)

Source: shallow clone of `main` (latest release v2.7.0, 2026-10-02). All paths are relative to the repo root.
The web frontend now talks **only to `/api/v2`** through the generated SDK in `frontend/src/client/generated`
(`frontend/src/helpers/apiUrl.ts`: `getApiBaseUrl()` returns `${root}/api/v2`).

Evidence tags used below:

- **[V]**: verified by reading the cited source.
- **[T]**: also pinned by a unit test (test file cited).
- **[P]**: verified by running my own hand transcription of the cited function under Node 26
  (`scratchpad/verify/qam.mjs`; nothing from the repo was executed). Use these as golden values for Dart tests,
  but double-check them against the TS before relying on a quirk.
- **[I]**: inference, not verified.

---

## 0. Priorities for the port

1. Quick Add Magic (`frontend/src/modules/quickAddMagic/*`) together with the task builder (`frontend/src/helpers/task.ts`,
   `frontend/src/composables/useQuickAddTask.ts`) and multi-line/subtask input (`frontend/src/helpers/parseSubtasksViaIndention.ts`).
   This is the largest and most quirk-laden piece. A 1058-line test file exists to translate.
2. Date semantics: zero-date handling, default due time, nearest-hour logic, shortcuts, relative reminders, repeat modes.
3. The filter string transformer (`frontend/src/helpers/filters.ts`) plus the exact filter strings used by Home, Upcoming,
   Gantt and saved filters.
4. Position math (`frontend/src/helpers/calculateItemPosition.ts`), and done/undo behaviour for repeating tasks.
5. Description HTML conventions (checklists, mentions, attachment images, task links). The server parses these.
6. Colors, identifiers, priorities, avatars/attachments/backgrounds (authenticated blobs), i18n list.

---

## 1. Quick Add Magic

### 1.1 Files

| File | Role |
|---|---|
| `frontend/src/modules/quickAddMagic/quickAddMagic.ts` | `parseTaskText(text, mode = 'vikunja', now = new Date())`, the pipeline |
| `.../prefixes.ts` | prefix tables and `PrefixMode` enum |
| `.../prefixParser.ts` | `getItemsFromPrefix`, `getProjectFromPrefix`, `getLabelsFromPrefix` |
| `.../textCleanup.ts` | `cleanupItemText`, `cleanupResult` |
| `.../priorityParser.ts` | `getPriority` |
| `.../repeatParser.ts` | `getRepeats` |
| `.../dateParser.ts` | `parseDate`, `getDateFromText`, `getDateFromTextIn`, plus private weekday/day/month helpers |
| `.../types.ts` | `ParsedTaskText {text, date: Date\|null, labels: string[], project: string\|null, priority: number\|null, assignees: string[], repeats: {type, amount}\|null}` |
| `.../quickAddMagic.test.ts` | 1058-line test suite |
| `frontend/src/helpers/replaceAll.ts` | case-insensitive global replace that escapes the search string |
| `frontend/src/helpers/time/calculateDayInterval.ts`, `getDateWithTime.ts`, `calculateNearestHours.ts` | used by the date parser |

### 1.2 Modes and prefixes [V] (`prefixes.ts`)

User setting: `settings.frontend_settings.quick_add_magic_mode` takes `'disabled' | 'vikunja' | 'todoist'` and defaults to `'vikunja'`
(`frontend/src/helpers/userSettings.ts` `defaultFrontendSettings()`).

| | label | project | priority | assignee |
|---|---|---|---|---|
| `vikunja` (PrefixMode.Default) | `*` | `+` | `!` | `@` |
| `todoist` | `@` | `#` | `!` | `+` |
| `disabled` | none: `PREFIXES.disabled === undefined`, so `parseTaskText` returns the text unchanged with every field empty | | | |

### 1.3 Pipeline order (`parseTaskText`) [V]

1. **Whole-text quote escape.** If `text.length >= 2` and the text starts and ends with the same quote (`"…"` or `'…'`), the
   result is `text.slice(1,-1)` and nothing else is parsed, in every mode including todoist [T]. The check runs before the `disabled` check, so even in `disabled` mode the quotes are stripped [V].
   Unmatched or mismatched quotes, or quotes only in the middle, are parsed normally [T].
2. If the mode is `disabled`, return the raw text.
3. `labels = getItemsFromPrefix(text, labelPrefix)`. Then `text = cleanupItemText(text, labels, labelPrefix)`.
4. `project = first(getItemsFromPrefix(text, projectPrefix))`. Only the first project counts; the others stay in the text [T].
   Remove it with `cleanupItemText`.
5. `priority = getPriority(text, '!')`. If found, remove `!<n>`.
6. `assignees = getItemsFromPrefix(text, assigneePrefix)`. These are **not** removed from the text at this stage.
7. `getRepeats(text)` removes the repeat phrase and sets `repeats`.
8. `parseDate(text, now)` removes the date/time phrase and sets `date`.
9. `cleanupResult`: run the label, project and priority cleanup once more, then `trim()`. Assignees are still not removed
   (comment: "to avoid removing @text where the user does not exist").

Because labels and project are extracted first and removed from the text, `*today` or `+today` is a label or project,
never a date [T]. Assignees are not removed, so `@today` stays in the text, but `today` itself is still not parsed as a
date [T]. That works because `parseDate` needs `(^| )today` and the `@` sits in front.

### 1.4 Item grammar: `getItemsFromPrefix(text, prefix)` [V]

```
parts = text.split(' ' + prefix)          // JS split with a string separator
if text.startsWith(prefix): parts.unshift(text.split(prefix)[1])
for each part with index >= 1:
   if part.startsWith(prefix): part = part.substring(1)
   if part[0] == "'": item = part.split("'")[1]
   elif part[0] == '"': item = part.split('"')[1]
   else: item = part.split(' ')[0]        // up to the next space
   if item != '': items.push(item)
return unique(items)                      // Set, insertion order kept
```

Consequences, each covered by a test or a probe:

- A prefix only counts when it starts the text or follows a space. `email@example.com` is never an assignee [T].
- `@email@example.com` gives the assignee `email@example.com`: only the first char after `' @'` is the prefix [T].
- Quoted items may contain spaces: `*'label with space'` or `*"label with space"` [T]. They may also contain parentheses: `*"a (a)"` [T].
- Duplicates collapse: `*label1 *label1 *label2` gives `['label1','label2']` [T].
- `@ alice` (prefix followed by a space) gives an empty item, which is ignored [P].

### 1.5 Removing parsed parts: `cleanupItemText(text, items, prefix)` [V]

For each non-empty item, `escaped = regexEscape(item)`, then these case-insensitive global regex replacements run in order,
each replacing with `''`:

```
\<prefix>'<escaped>'␠   \<prefix>'<escaped>'   \<prefix>"<escaped>"␠   \<prefix>"<escaped>"   \<prefix><escaped>␠   \<prefix><escaped>
```

(The prefix is always backslash-escaped. `\*`, `\+`, `\!`, `\@`, `\#` are all valid escapes in JS and Dart regex.)

Effects:

- The trailing space after an item is eaten, but the leading space is not, so double spaces can remain.
  Todoist test: `'Lorem Ipsum today @label #project !2 +user'` gives text `'Lorem Ipsum  +user'` [T].
- The replacement is case-insensitive and also hits **substrings** of longer tokens: `*a` would also strip the `*a` inside `*abc` [I from regex].

### 1.6 Priority: `getPriority(text, '!')` [V]

Take all `!`-items in order and return the first whose `parseInt(item)` is one of `PRIORITIES` = `{UNSET:0, LOW:1, MEDIUM:2,
HIGH:3, URGENT:4, DO_NOW:5}` (`frontend/src/constants/priorities.ts`).

- `!9999 !1` gives priority 1, and the text keeps `!9999` [T].
- `!0` is accepted and gives priority 0 (UNSET), removed from the text [P].
- `!6` is not accepted and stays in the text [P].
- `parseInt` semantics: `!3abc` gives 3, and the cleanup then removes `!3`, leaving `abc` [I]. Use a `^\d+` parse in Dart.

### 1.7 Repeat grammar: `getRepeats` [V]

```
/(^| )(((every|each) (([0-9]+|one|two|three|four|five|six|seven|eight|nine|ten) )?(hours?|days?|weeks?|months?|years?))|(annually|biannually|semiannually|biennially|daily|hourly|monthly|weekly|yearly))($| )/ig
```

- The amount is `one`…`ten`, a number, or omitted (then 1).
- The keyword table (`results[2]`) maps:
  - `biennially` to years×2
  - `biannually` and `semiannually` to months×6
  - `yearly` and `annually` to years
  - `daily` to days
  - `hourly` to hours
  - `monthly` to months
  - `weekly` to weeks
  - otherwise the unit group decides
- The default type is `hours`.
- The matched text (minus a trailing space) is removed with JS `String.replace(string)`, which replaces the **first occurrence only**.
- Keywords inside words are ignored (`wordweeklynotword`) [T].
- **Quirk [V][P]:** the regex is case-insensitive but the `switch` statements compare case-sensitively. `Every Day`
  and `Daily` therefore both parse as **every 1 hour**. Lower-case input works as documented.
- Golden cases in the test: `every 1 hour`, `every hour`, `every 5 hours`, `every day`, `every 2 days`, `every week`,
  `every 3 weeks`, `every month`, `every 2 months`, `every year`, `every 4 years`, `every one`…`every ten hours`, the 9 keywords.
  The `… at 11:42` variants yield **today** at 11:42 [T].

### 1.8 Date grammar: `parseDate(text, now)` [V]

The checks run in this order, and the first hit wins. The `(^| )word` checks have **no trailing boundary**.

| # | Matcher (case-insensitive) | Result date | Time part |
|---|---|---|---|
| 1 | `(^| )today` | today (`new Date()`) | `getDateWithTime` (see 2.4) |
| 2 | `(^| )tonight` | today | 21:00 (seconds and ms from `getDateWithTime` stay 0) |
| 3 | `(^| )tomorrow` | +1 day | default time |
| 4 | `(^| )next monday` | `+calculateDayInterval('nextMonday')`: **0 on a Monday, so today** | default time |
| 5 | `(^| )this weekend` | `+(6-day)%6`: Sat or Sun gives today | default time |
| 6 | `(^| )later this week` | +2, or +0 on Fri/Sat/Sun | default time |
| 7 | `(^| )later next week` | the above +7 | default time |
| 8 | `(^| )next week` | +7 | default time |
| 9 | `(^| )next month` | the 1st of next month | default time |
| 10 | `(^| )end of month` | the last day of this month | default time |
| 11 | weekday `/(^| )(next )?(monday\|mon\|tuesday\|tue\|wednesday\|wed\|thursday\|thu\|friday\|fri\|saturday\|sat\|sunday\|sun)($| )/` on `text.toLowerCase()` | the next occurrence, distance `(day+7-now.getDay())%7`, so **0 means today**. `next fri` is the same as `fri` | **keeps the current clock time of `now`** (it mutates and returns the `now` object) [P] |
| 12 | ordinal `(^| )(([1-2][0-9])\|(3[01])\|(0?[1-9]))(st\|nd\|rd\|th\|\.)(?=$\| at \| @ \| <month>)` | day-of-month. If it is in the past, roll the month forward; on overflow (e.g. 31st) re-set the day. Then `getMonthFromText` sets the month from any `\b<month>\b` in the text and removes that month word | keeps the current time [P] |
| 13 | `in <n> (hours?\|days?\|weeks?\|months?)` (no `^| ` anchor) | `now + n` units | keeps the time, so hours add up |
| 14 | `getDateFromText` (below) | absolute date | 00:00 local (JS `new Date('M/D/YYYY')`) |
| 15 | none of the above, but `addTimeToDate(text, new Date(now), foundText)` found a time | today | the parsed time |

`<month>` is the alternation `(january|february|march|april|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)`. The long names come first, and `may` only appears in the short list.

**Time suffix (`addTimeToDate`)** [V][T]:

1. First remove the matched date phrase with the case-insensitive `replaceAll`.
2. Then search ` (at|@) ([0-9][0-9]?(:[0-9][0-9])?( ?(a|p)m)?)` (case-insensitive).
3. For `pm`, add 12 unless the hour is 12. For `12 am`, use 0.
4. Set the hours and minutes, and zero seconds and ms.
5. Remove the matched time phrase and `trim()`.

Examples from the test: `at 15:00`, `@ 15:00`, `@ 3pm`, `at 3 pm`, `at 3:12 AM` (3:12), `at 12:00 pm` (12:00),
`at 12:00 am` (0:00). The time is searched anywhere in the remaining text, before or after the date
(`'Something at 10:00 in 5 days'` gives +5d 10:00) [T]. Out-of-range hours roll over: `at 25:00` gives 01:00 the next day [P].
A bare `5pm` without `at`/`@` is not a time [P].

**`getDateFromText`** [V]:

1. Absolute patterns are tried in order, each wrapped by `matchDateAtBoundary`:
   - `M/D[/YY|YYYY]`
   - `YYY[Y]/M/DD`
   - `YYY[Y]-M-DD`
   - `D.M[.YY|YYYY]`

   `matchDateAtBoundary` uses `(^| )<pat>($| )`. A match in the middle of the text is only accepted when it is directly followed by
   `at ` or `@ `. So `The 9/11 Report` gives no date [T], `meeting 9/11 at 10:00` gives a date [T], and
   `The 9/11 Report due 10/12` takes 10/12 [T].
   The candidate string is `${month}/${day}/${year ?? now.getFullYear()}`. If JS `new Date()` says it is invalid, try
   `${day}/${month}/${year}`, so `27/01` becomes Jan 27 [T]. Without a year: if the date is earlier than `now`, add 1 year [T].
2. If nothing matched: `(^| )(<month> [0-9][0-9]?|[0-9][0-9]? <month>)` with **no boundary at all** (no end check, no
   middle-of-text guard). The year is the current year, plus 1 if the date is in the past.
3. JS `Date` parsing behaviour that must be emulated [P with Node]:
   - `new Date('02/30/2021')` gives **Mar 2 2021**: the day is accepted up to 31 and overflows.
   - `'13/01/2021'` is Invalid.
   - Two-digit years: `1/1/27` gives 2027, `6/7/21` gives 2021, `01.02.25` gives 2025 [T]. V8 maps 0–49 to 20xx and 50–99 to 19xx [I].
   - `'12 dec 2026'` and `'dec 12 2026'` both parse.

**Golden table from `quickAddMagic.test.ts` 'Parse date from text'** (now = 2021-06-24; input placed at the end and at the start;
the expected title is `Lorem Ipsum`):

```
06/08/2021→2021-6-8   6/7/21→2021-6-7   27/07/2021,→null   2021/07/06→2021-7-6   2021-07-06→2021-7-6
27 jan→2022-1-27  27/1→2022-1-27  27/01→2022-1-27  16/12→2021-12-16  01/27→2022-1-27  1/27→2022-1-27
jan 27 / Jan 27 / january 27 / January 27→2022-1-27   feb 21…June 21→2022-x-21 (past→next year)
21st June→2021-6-21  2nd March→2021-3-2  3rd April→2021-4-3  1st January→2021-1-1  22nd December→2021-12-22
23rd October→2021-10-23  4th July→2021-7-4  15th August→2021-8-15  31st December→2021-12-31  5th Mar→2021-3-5  12th Sep→2021-9-12
jul 21…dec 21→2021-x-21   01.02.2021→2021-2-1   01.02→2022-2-1   01.10→2021-10-1   01.02.25→2025-2-1
```

Note that ordinal+month results can be in the past (`2nd March` gives 2021-3-2 when now is June 2021). The year roll-over
only applies to rule 14.

The 'Parse date from text in' table (now 2021-06-24 12:00) is also in the test:

- `in 1 hour` → 13:00
- `in 1 week` → 7-1
- `in 1 month` → 7-24
- `Something 17th at 10:00` → 2021-7-17 10:00
- `Something sep 17th at 10:00` → 2021-9-17 10:00
- `2nd March at 5pm` → 2021-3-2 17:00
- `15th August @ 9am` → 8-15 9:00
- `Some task Mar 8th` → date 2021-3-8 12:00, newText `Some task`

**Things that must NOT parse** [T]:

- `renewed`, `github`, `fix monitor stand`, `order wedding cake`, `investigate thumping noise`, `iron frilly napkins`,
  `take photo of saturn`, `fix sunglasses`, `monitor blood pressure`, `buy almonds`, `Renovation`, `Remark`,
  `Renovation - 2nd Floor Bath`, `Remark - 13th floor`, `13th floor - remark` (each at the start, middle and end)
- `Lorem Ispum v1.1.1`
- `https://some-url.org/blog/2019/1/233526-some-more-text`
- `The 1.2 formula`
- `a]7/8 debate`
- any weekday glued to other letters

**Known false positives worth replicating or deliberately fixing** [P]:

- `Read todays paper` gives today's date and text `Read s paper` (no trailing boundary after `today`).
- `Plan next weekend trip` gives +7 days and text `Plan end trip` (matches `next week`).
- `buy 12 decorations` gives Dec 12 and text `buy orations` (month rule 14.2 has no boundaries).
- `Something sep 17th` when today is Oct 8 gives **Sep 17 of this year (past)**.
- `x 29th feb` in 2026 gives **Mar 1 2026** (day overflow).
- Weekday and ordinal results carry the current `HH:mm:ss.SSS` of `now`. Only rules 1–10 use the default time.
- Only `next monday` is special-cased. On a Monday it means **today**, and `calculateDayInterval` tests pin this [T].

**Languages:** all keywords are **English only**. There is no i18n of quick-add grammar anywhere [V]. The help text in
`frontend/src/components/tasks/partials/QuickAddMagic.vue` is translated, but the keywords are not.

### 1.9 From parse result to API calls

`frontend/src/composables/useQuickAddTask.ts` and `frontend/src/helpers/task.ts` `buildQuickAddTask` [V][T]:

1. `parsed = parseTaskText(input.title, mode)` (the date anchor `now` is the real clock).
2. **Magic-only title**: if `parsed.text === ''`, then `magicOnly = true`. The task is created with the **raw input title,
   trimmed**, in the input project. There is no date, label, assignee, priority or repeat, and no label is created
   (`helpers/task.test.ts` 'keeps the raw input title…', `useQuickAddTask.test.ts` 'creates no label when the whole title is magic',
   'keeps a title that is only a project prefix in the input project').
3. **Project resolution** (`findProjectId`):
   1. If a project was parsed, use `ensureProjects()`. This is the full list including archived projects, fetched with
      `projectsList({is_archived:true, expand:'permissions'})`.
   2. Match `findProjectByExactTitle` (case-insensitive equality on `title`), else a case-insensitive match on `project.identifier`.
   3. If nothing matched: use the route's `projectId` if it is > 0, else `input.project_id`.
   4. If the id is <= 0, throw `Error('NO_PROJECT')`. The UI shows `project.create.addProjectRequired` ("Please specify a project
      or set a default project in the settings.").
4. **Assignee resolution**, per parsed name:
   1. `GET /projects/{id}/users/search?q=<name>` (`searchProjectUsers`).
   2. If **exactly one** user comes back, accept it when `username`, `name` or `email` **contains** the query (case-insensitive).
      If several come back, require case-insensitive **equality** on one of those fields.
   3. Unresolved names stay in the title. Resolved ones are stripped with `cleanupItemText(text, matches, assigneePrefix)`
      [T: `'Task @alice @missing *label'` gives title `'Task @missing'`].
5. **Due date**: `parsed.date`, or, when `repeats` is set but no date, `getDateWithTime(new Date())`, i.e. today at the default
   time (comment: "Without a due date, a repeating task never becomes due") [T]. Sent as `toISOString()` (UTC, with ms).
6. **Repeat conversion**: `repeat_after = repeatAfterToSeconds(repeats)` and `repeat_mode = (type==='months' && amount===1) ? 1 : 0`.
   **`periodToSeconds` only knows minutes, hours, days and weeks and returns 0 for months and years**
   (`frontend/src/helpers/time/period.ts`).
   - `every month` / `monthly` give `repeat_mode=1, repeat_after=0` [T].
   - `every 2 months`, `biannually`, `yearly` and `every 4 years` give `repeat_after=0, repeat_mode=0`, i.e. **no repeat**
     [V; looks like a bug]. Decide whether to replicate this.
7. **Priority**: `parsed.priority ?? 0`.
8. **Default reminders**: `settings.frontend_settings.quick_add_default_reminders` (`[{relative_period}]`) are applied **only
   if there is a due date**, each as `{relative_period, relative_to:'due_date'}` regardless of the stored relative_to [T].
9. **Create order**:
   1. `POST /projects/{project}/tasks` (v2 `tasksCreate`) with `taskWriteBody` (section 12).
   2. Add each resolved assignee: `POST /tasks/{id}/assignees {user_id}`.
   3. Labels: `ensureLabelsExist` → `POST /tasks/{id}/labels {label_id}`.

   Steps 2 and 3 run sequentially, or in parallel when `/info` reports `concurrent_writes` (`runWrites`;
   SQLite deadlocks on concurrent writes per `frontend/src/helpers/runWrites.ts`).
10. **Label auto-create** (`ensureLabelsExist`):
    1. Dedupe the titles. Use the cached labels and refetch all labels if any title is missing.
    2. Match by case-insensitive exact title (`getLabelByExactTitle`).
    3. Missing labels are created with `POST /labels {title, hex_color: random}`. The color comes from a fixed 13-color
       palette (`frontend/src/helpers/color/randomColor.ts`: `#ffbe0b #fd8a09 #fb5607 #ff006e #efbdeb #8338ec #5f5ff6
       #3a86ff #4c91ff #0ead69 #25be8b #073b4c #373f47`). `colorFromHex` strips `#` before sending.
    4. A failed create never fails the task. Skipped titles are reported once: `task.label.createFailed` = "These labels could
       not be created and were not added: {labels}" [T].
11. **Multi-line input** (`frontend/src/components/tasks/AddTask.vue`):
    1. Enter submits and Shift+Enter inserts a newline.
    2. All labels of all lines are pre-created first. The pre-pass does not check magicOnly, so `*Urgent` alone creates the
       label "Urgent" but does not attach it [I from code].
    3. The project per line is the parsed project, else the route project, else `settings.default_project_id`.
    4. Tasks go through `bulkCreateTasksMutationOptions` (`frontend/src/client/queries/taskMutations.ts`): grouped by project,
       chunks of 100, `POST /projects/{project}/tasks/bulk {tasks:[...]}`. The **last chunk is submitted first** because
       "the API inserts batches at the top".
    5. Then parent relations are created: for a child, `POST /tasks/{child}/relations {other_task_id: parent,
       relation_kind:'parenttask'}`.
12. **`parseSubtasksViaIndention(text, mode)`** [V][T] (`frontend/src/helpers/parseSubtasksViaIndention.ts`):
    1. Split on `[\r\n]+` and drop lines that are blank or whitespace-only.
    2. Strip the common leading indent of the first line. If any later line has no indent, nothing further is cut.
    3. Strip list markers with `^((\* |\+ |- )(\[ \] )?)`.
    4. A line indented more than the previous one has as parent the nearest earlier line with less indent.
    5. The project is taken from the line itself, or inherited from the parent line's project prefix.

    Tests cover two-, three- and four-level trees, `* ` markers (`* parent task` / `  * sub task one`), an indented first line, inheriting `+list` from the parent, and first-line indent removal. The `- ` and `+ ` and `[ ] ` markers come from the regex only [V].

### 1.10 Where the parser is also used

- `frontend/src/components/quick-actions/QuickActions.vue` (search palette).
  - Search mode: text without assignees means TASKS. Only a project means PROJECTS. Only assignees means TEAMS.
  - The task search sends `q=<text>`, `sort_by=['done','relevance']`, and `filter` built as
    `' project = <id>'` + `'labels in <ids>'`. Both are concatenated **without `&&`**, which is a bug when both are present [V].
- `frontend/src/components/tasks/partials/QuickAddMagic.vue`: the help popup.

### 1.11 Dart porting notes

- Dart `RegExp` supports named groups `(?<x>…)`, lookahead and `caseSensitive:false`. JS `/g` with `exec` loops maps to `allMatches`.
- JS `str.replace('literal', '')` replaces only the **first** occurrence. Use `replaceFirst`. JS `replaceAll` from `helpers/replaceAll.ts`
  is case-insensitive global: use `replaceAll(RegExp(RegExp.escape(s), caseSensitive:false), '')`.
- JS `str.split(sep)` with a string separator behaves like Dart `split`. Watch the `[1]` access on short arrays: JS returns `undefined`,
  Dart throws.
- `parseInt(' 21st')` gives 21. Implement a lenient leading-integer parse.
- Replace JS `new Date(string)` with an explicit parser for `M/D/Y`, `D/M/Y` fallback, `<Mon> D Y` and `D <Mon> Y`. Emulate:
  - the V8 day ≤ 31 overflow
  - month > 12 being invalid
  - the two-digit year mapping
- Dart `DateTime(y, m, d)` overflows like JS `setDate`/`setMonth`, so day-of-month roll logic ports directly.
  JS `setMonth(m+1)` on the 31st overflows the same way.
- Inject `now` everywhere. The TS uses `new Date()` internally for rules 1–10 and `getMonthFromText`. Tests use fake timers.

---

## 2. Date and time helpers

### 2.1 Zero dates and clearing

`frontend/src/helpers/parseDateOrNull.ts` [V][T]:

- The API sends `0001-01-01T00:00:00Z` for "no date".
- `parseDateOrNull` returns null for null, undefined, `''`, invalid values, and any date whose `getUTCFullYear() <= 1`.
- `dateIsValid`, `formatDate`, `formatISO` and `toISOStringOrNull` all go through it
  (`frontend/src/helpers/time/formatDate.test.ts`, `toISOStringOrNull.test.ts`).

To clear a date, the client sends `API_ZERO_DATE = '0001-01-01T00:00:00Z'` for empty `due_date`, `start_date`, `end_date`
and for an empty `reminders[].reminder` (`frontend/src/client/queries/taskMutations.ts` `taskWriteBody`) [V].

### 2.2 `createDateFromString`

`frontend/src/helpers/time/createDateFromString.ts`: if the string has no `T` but has `-`, replace `-` with `/` (Safari fix),
then `new Date()`. In Dart, parse `YYYY-MM-DD HH:mm` explicitly.

### 2.3 Day intervals

`frontend/src/helpers/time/calculateDayInterval.ts` [V][T] (`currentDay` uses JS `getDay()`, where 0 is Sunday):

| key | formula | Mon | Tue | Wed | Thu | Fri | Sat | Sun |
|---|---|---|---|---|---|---|---|---|
| today | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| tomorrow | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| nextMonday | `(d+(8-2d))%7` | **0** | 6 | 5 | 4 | 3 | 2 | 1 |
| thisWeekend | `(6-d)%6` | 5 | 4 | 3 | 2 | 1 | 0 | 0 |
| laterThisWeek | Fri/Sat/Sun→0 else 2 | 2 | 2 | 2 | 2 | 0 | 0 | 0 |
| laterNextWeek | laterThisWeek+7 | 9 | 9 | 9 | 9 | 7 | 7 | 7 |
| nextWeek | 7 | 7 | … | | | | | 7 |

### 2.4 Default time for date-only input

`frontend/src/helpers/time/getDateWithTime.ts` and `calculateNearestHours.ts` [V][T]:

- `settings.frontend_settings.default_due_time` must match `^(\d{2}):(\d{2})$` with hours ≤ 23 and minutes ≤ 59
  (`'9:45'` → null, `'24:00'` → null, `'12:60'` → null). If valid, use it.
- Otherwise use `calculateNearestHours(now)`: the next breakpoint among 9, 12, 15, 18, 21. "At HH:00 exactly" counts as that
  breakpoint, and after 21:00 (or 21:01+) the result is **9 on the same day** (no day roll).
  - Examples: 05:xx → 9, 09:00 → 9, 10:15 → 12, 12:00 → 12, 13:xx → 15, 16:xx → 18, 22:xx → 9.
- `getDateWithTime(d)` sets h:m and zeroes seconds and ms.

### 2.5 Datepicker behaviour

`frontend/src/components/input/DatepickerInline.vue` [V]:

- Clicking a calendar day keeps the current time if a date is already set. Otherwise it uses `default_due_time`, or
  **12:00** if none is configured.
- Shortcuts use `getDateWithTime(day)` (the nearest-hour logic) unless a time is already set.
- `minDate` clamps the value.

Shortcuts come from `frontend/src/helpers/time/dateShortcuts.ts` `buildDateShortcuts(now)` [V][T]:

- Keys in order: `today, tomorrow, nextMonday, thisWeekend, laterThisWeek, nextWeek, nextWeekend, endOfMonth, inAMonth`.
- Rules:
  - `nextWeekend` is the Saturday after this week's. On Sunday it is the very next Saturday.
  - `inAMonth` is +1 month, clamped to the last day of the month (Jan 31 → Feb 28).
  - Each date is the start of its day.
  - When two shortcuts land on the same day, the later one is dropped.
  - From 21:00 on, `today` is hidden, and `thisWeekend` is hidden on Sunday.
- Test vectors:
  - Fri 2026-09-11 10:00 → `today, tomorrow, nextMonday, nextWeek, nextWeekend, endOfMonth, inAMonth`
  - Mon 2026-09-14 → `today, tomorrow, thisWeekend, laterThisWeek, nextWeek, nextWeekend, endOfMonth, inAMonth`
  - Tue 2026-09-15 → all 9
  - On 2026-09-30, `endOfMonth` is hidden (it equals today)

`frontend/src/components/tasks/partials/DeferTask.vue`: buttons +1, +3 and +7 days applied to the current due date (or now),
keeping the time. The picker change is debounced by 500 ms. The update sends the full task with the new `due_date` [V].

### 2.6 Display formatting

`frontend/src/helpers/time/formatDate.ts` [V][T]. Settings: `frontend_settings.date_display` and `time_format`
(`frontend/src/constants/dateDisplay.ts`, `timeFormat.ts`). The defaults are `relative` and `24h` (`userSettings.ts`).

| date_display | output (dayjs format, or Intl) |
|---|---|
| `relative` (default) | `dayjs(date).from(now)`. If `|date-now| < 60s`, "just now" (`time.justNow`). `now` ticks every 60 s (`composables/useGlobalNow.ts`) |
| `mm-dd-yyyy` / `dd-mm-yyyy` / `yyyy-mm-dd` | `MM-DD-YYYY` etc. followed by ` HH:mm` (24h) or ` hh:mm A` (12h) |
| `mm/dd/yyyy` / `dd/mm/yyyy` / `yyyy/mm/dd` | same, with slashes |
| `dayMonthYear` | `Intl.DateTimeFormat(locale,{day:'numeric',month:'long',year:'numeric',hour:'numeric',minute:'numeric',hour12})` |
| `weekdayDayMonthYear` | the same plus `weekday:'long'`. Used by `formatDateLong` for tooltips |

`formatDateShort` uses dayjs `lll`. The locale goes through `DAYJS_LOCALE_MAPPING` (`frontend/src/i18n/useDayjsLanguageSync.ts`, section 17).

### 2.7 Week start

`settings.week_start` is 0–6, with 0 = Sunday (`pkg/models/user_settings.go` `WeekStart`, `valid:"range(0|6)"`).
It is used only by the calendar grid:

- `frontend/src/helpers/time/calendarGrid.ts` `buildMonthGrid(year, month, weekStart)` always returns 42 cells, with
  `lead = (firstDay.getDay() - weekStart + 7) % 7`.
- `weekdayOrder(ws)` is `[(i+ws)%7]` [V][T].
- Server date math (`now/w`) does **not** use `week_start`. It uses go-datemath's own week rounding in `filter_timezone`
  (`pkg/models/task_collection_filter.go` `getValueForField`) [V]. The week start of go-datemath
  (`github.com/jszwedko/go-datemath v0.1.1-…`, `go.mod`) is not verified; I believe it is Monday [I].

### 2.8 Timezone handling [V]

- The browser shows and edits all dates in the **device's** local zone (JS `Date` and dayjs). They are serialized with `toISOString()` (UTC).
- `settings.timezone` (IANA name, `''` when unset; the list comes from `GET /user/timezones`) is passed as **`filter_timezone`**
  on every task-list request (`frontend/src/composables/useTaskList.ts`, `ShowTasks.vue`, `useGanttTaskList.ts`, `ProjectKanban.vue`).
  The server uses it to round date math such as `now/d`. When it is empty, the server falls back to its configured zone
  (`config.GetTimeZone()`) (`pkg/models/task_collection_filter.go` `getTaskFiltersFromFilterString` / `getValueForField`).
  Saved filters without a timezone get the user's (`pkg/models/task_collection.go:325-330`).
- Inconsistency: time-entry lists pass the **device** zone instead (`frontend/src/composables/useTimeTracking.ts:39`).
- The web never auto-fills `settings.timezone` from the device [V: no writer found besides the settings form].
  The server also uses it to send reminders "in their local time" (`pkg/models/user_settings.go` doc).
  - Porting advice [I]: show device time like the web does. Offer to set `settings.timezone` from the device when it is empty
    or differs, because reminder emails and date-math filters depend on it.

### 2.9 Period conversion

`frontend/src/helpers/time/period.ts` [V][T]:

- `secondsToPeriod(s)`: if `s % 86400 == 0`, return weeks when `s % 604800 == 0`, else days. Otherwise return hours when
  `s % 3600 == 0`, else **minutes** (fractional values are possible). There is never months or years.
- `periodToSeconds(n, unit)`: minutes, hours, days and weeks convert. **Anything else gives 0.**
- `parseRepeatAfter(604800)` gives `{type:'weeks',amount:1}` [T].

### 2.10 Other time helpers (with tests)

| Helper | Behaviour |
|---|---|
| `roundToNaturalDayBoundary(date, isStart)` | start → 00:00. End → 00:00 if before noon, else 23:59:59.999 |
| `smartFillStart(entries, defaultStart, now)` | time tracking: the latest `end_time`, else today at `defaultStart` (default `'09:00'`), capped at now |
| `dateMath.ts` | `startOfDay`, `addDays`, `isSameDay`, and `isDayBetween` (exclusive on both ends) |
| `hourToDaytime` | night if h<5 or h>23, morning if h<11, day if h<18, evening if h<23, else night |
| `useDaytimeSalutation` | greeting picked from a pool by `stringHash(\`${y}-${m}-${d}_${bucket}_${userCreatedMs}\`) % pool.length`. `stringHash` is djb2 with 32-bit wrap, then `>>>0` |

---

## 3. Repeat modes and how the UI presents them

- Constants (`frontend/src/types/IRepeatMode.ts`) [V]:
  - `0 REPEAT_MODE_DEFAULT`: every `repeat_after` seconds
  - `1 REPEAT_MODE_MONTH`: monthly, `repeat_after` is ignored
  - `2 REPEAT_MODE_FROM_CURRENT_DATE`: `repeat_after` counted from the completion time
- Repeat types: `seconds|minutes|hours|days|weeks|months|years` (`frontend/src/types/IRepeatAfter.ts`).

**Editor** (`frontend/src/components/tasks/partials/RepeatAfter.vue`) [V]:

- Preset buttons: "Every Day" (1 day), "Every Week" (1 week), "Every 30 Days" (30 days).
- Mode select: Default / "Monthly" / "From completion date".
- If the mode is not Monthly, show "Each [amount] [Hours|Days|Weeks]". The UI offers only hours, days and weeks.
- Existing seconds are displayed via `secondsToPeriod`, so 30 days shows as 30 days and 1209600 as 2 weeks.
- `updateData` does **nothing** when the mode is 0 or 2 and the amount is 0. It errors with "Please enter more than 0." when
  the mode is 0 and the amount is < 0.
- "Remove repeat" sets `repeat_after=0, repeat_mode=0` (`frontend/src/views/tasks/TaskDetailView.vue:1241`).

**Is repeating** [V]:

- `SingleTaskInProject.vue:272` and `KanbanCard.vue:192` use `repeat_after > 0 || repeat_mode === 1`.
- The task detail shows the repeat field when `repeat_after>0 || repeat_mode !== 0` (`TaskDetailView.vue:1023`).
- Backend: `isRepeating()` is `RepeatAfter>0 || RepeatMode==Month` (`pkg/models/tasks.go:219`).

**What the server does on done=true** (needed to explain the UI and for offline prediction). From `pkg/models/tasks.go` `updateDone` [V]:

- Mode 0:
  - Every set date (due, start, end, each reminder) advances by whole multiples of `repeat_after` until it is strictly after now,
    and at least one interval.
  - `done` is reset to false.
- Mode 1:
  - Due date and reminders get +1 calendar month in the **server** time zone.
  - When start and end are both set, end keeps its distance to start.
- Mode 2:
  - Due date becomes now + interval.
  - Reminders shift so the earliest one lands on now + interval.
  - Start and end keep their offset to due, or to start when there is no due date.
- All repeating modes also uncheck the checklist in the description: `data-checked="true"` becomes `false`, and the
  `checked` attribute is removed from checkbox inputs (`resetDescriptionChecklist`).
- `done_at` is set to now. Un-marking clears `done_at`.

The response of the PATCH therefore comes back with `done:false` and new dates. The client must replace its cached copy with the
response (`mergeTask`, see section 11).

---

## 4. Reminders

**Model**: `TaskReminder {reminder: ISO|'', relative_period: seconds (signed), relative_to: ''|'due_date'|'start_date'|'end_date'}`
(`frontend/src/types/IReminderPeriodRelativeTo.ts`, `createReminderDraft` in `frontend/src/helpers/task.ts`) [V][T].

**Server** (`pkg/models/tasks.go` `updateRelativeReminderDates`) [V]:

- For a relative reminder the server **computes the absolute `reminder`** = date(relative_to) + relative_period, and clears it
  if that date is unset.
- `relative_period != 0` without `relative_to` gives the error `ErrReminderRelativeToMissing`.
- Porting [I]: schedule local notifications from the server-computed `reminder` field. Recompute locally only for offline edits.

**Editor** (`frontend/src/components/tasks/partials/ReminderDetail.vue`, `ReminderPeriod.vue`, `Reminders.vue`) [V]:

- Presets, all with `relative_to = defaultRelativeTo`: `0` (on the date), `-2h`, `-1d`, `-3d`, `-7d`, `-30d`.
- `defaultRelativeTo` in the task detail is `due_date` if a due date is set, else `start_date`, else `end_date`, else `null`.
  With `null`, only an absolute reminder can be added (`TaskDetailView.vue:808`).
- Relative form:
  - Amount input with units `minutes|hours|days|weeks`.
  - Direction `before (-1)` / `after (+1)`.
  - `relative_to` select, unless locked.
  - Emits `relative_period = sign * periodToSeconds(|n|, unit)` and `reminder=''`.
  - Quirk: on load `sign` is never initialised from an existing positive period, so it stays `-1` [V].
- Absolute form: the picked date's `toISOString()`, with `relative_to=''` and `relative_period=0`.
- Label text (`formatReminder`):
  - Period 0 gives "On the due date", "On the start date" or "On the end date".
  - Otherwise `"{amount} {unit} before|after {type}"`, where unit is a pluralised `time.units.*` from `secondsToPeriod`
    and type is "Due Date", "Start Date" or "End Date". A period ≤ 0 counts as *before*.
- An absolute reminder shows `formatDisplayDate`. It is overdue when `parseDateOrNull(reminder) < now`, and `now` ticks every second.

**Quick-add defaults**: `frontend_settings.quick_add_default_reminders: [{relative_period}]`, edited in
`frontend/src/views/user/settings/GeneralSettingsForm.vue`. They are always stored without `relative_to` and applied as `due_date` (see 1.9).

---

## 5. Priorities

| value | i18n key | en | List/Kanban label styling (`PriorityLabel.vue`) |
|---|---|---|---|
| 0 | `task.priority.unset` | Unset | — |
| 1 | `task.priority.low` | Low | `negligible` (info color) |
| 2 | `task.priority.medium` | Medium | `not-so-high` (warning) |
| 3 | `task.priority.high` | High | `high-priority` (danger, exclamation-circle icon) |
| 4 | `task.priority.urgent` | Urgent | high-priority |
| 5 | `task.priority.doNow` | DO NOW | high-priority |

The label is shown only if `!done && priority >= minimumPriority`. `minimumPriority = frontend_settings.minimum_priority || 2`,
so 0 (falsy) falls back to MEDIUM (`frontend/src/components/tasks/partials/PriorityLabel.vue`) [V]. The task detail shows the
priority field when `priority !== 0`.

---

## 6. Colors [V][T]

| Concern | Rule | Source |
|---|---|---|
| Wire format | `hex_color` is sent **without `#`**. `colorFromHex('#ffffff')` gives `'ffffff'` (takes `substring(1,7)`) | `frontend/src/helpers/color/colorFromHex.ts`; applied in `labels.ts` `labelBody`, `projects.ts` `projectBody`, `taskMutations.ts` `taskWriteBody` |
| Read side | projects are normalised to `#rrggbb` (`normalizeProject`) | `frontend/src/client/queries/projects.ts:107` |
| Read side | tasks use `getHexColor(c)`: `''` or `'#'` gives undefined, otherwise a `#` is prefixed | `frontend/src/helpers/task.ts` |
| Read side | labels use `getLabelColor`: `''`, `#…` and `var(…)` pass through, otherwise a `#` is prefixed | `frontend/src/composables/useLabelStyles.ts` |
| Contrast text | `colorIsDark(c)` (misnamed: true means the **background is light**). Steps: parse `rrggbb`, sRGB linearise (`v<=0.04045 ? v/12.92 : ((v+0.055)/1.055)^2.4`), `L=0.2126R+0.7152G+0.0722B`, return `L > 0.1791`. Empty, `#` or undefined return true | `frontend/src/helpers/color/colorIsDark.ts` |
| Contrast text | `getTextColor(bg)` is `colorIsDark(bg) ? '#000' : '#fff'`. The test asserts ≥ 4.5:1 for a 6×6×6 sweep, and `#e74c3c` and `#4287f5` give `#000` | `frontend/src/helpers/color/getTextColor.ts` and test |
| Label chip | background is the color or `var(--grey-200)`. Text is `getTextColor(color)` or `var(--grey-800)` | `useLabelStyles.ts` |
| Random label color | the 13-entry palette from 1.9 | `frontend/src/helpers/color/randomColor.ts` |
| Color picker defaults | `#1973ff #7F23FF #ff4136 #ff851b #ffeb10 #00db60`. Accepts 3- or 6-char values without `#`. "Reset" emits `''` | `frontend/src/components/input/ColorPicker.vue` |
| Background dimming | `frontend_settings.background_brightness` (0–100 or null) is applied as CSS `filter: brightness(N%)` | `frontend/src/components/home/ContentAuth.vue:21`, bounds in `GeneralSettingsForm.vue:451` |

---

## 7. Identifiers, titles and small display rules [V][T]

- **Task identifier.** The server sets `identifier = project.identifier + '-' + index`, or `'#' + index` when the project has
  no identifier (`pkg/models/tasks.go:505`). The client applies `getTaskIdentifier(task)`: it returns `identifier` unless it is
  empty or equals `-${index}`, in which case it returns `#${index}`.
  Tests: `{identifier:'WORK-2',index:2}` gives `WORK-2`, `{identifier:'-2'}` gives `#2`, `{index:2}` gives `#2`, and null gives `''`
  (`frontend/src/helpers/task.ts`, `task.test.ts`).
- **Project title** (`frontend/src/helpers/getProjectTitle.ts`):
  - id -1 shows the translated "Favorites" (`project.pseudo.favorites.title`).
  - The literal title `Inbox` shows `project.inboxTitle`.
  - The literal title `My Open Tasks` shows `project.myOpenTasksFilterTitle`. The backend creates these default names in English.
- **Overdue** (List and Kanban): `!done && due > epoch && due <= now`, re-evaluated every 60 s.
- **User display name**: `name || username || ''` (`frontend/src/helpers/user.ts`).
- **Checklist progress** (`frontend/src/helpers/checklistFromText.ts`, `ChecklistSummary.vue`):
  - Count regex `data-checked="(true|false)"` matches in the description HTML.
  - Show "{checked} of {total} tasks", or "{total} tasks" when all are done.
  - The circle progress is `checked/total`.
- **Empty description**: `'' || '<p></p>'` (`frontend/src/helpers/editorContentEmpty.ts`).
- **File size**: `getHumanSize` divides by 1024 while the size is > 1024. Units B, KB, MB, GB, TB; two decimals, trailing zeros dropped
  (`frontend/src/helpers/getHumanSize.ts`).
- **Notification text** (`frontend/src/helpers/notification.ts`) [T]. The strings are hard-coded English, not i18n:

  | name | text |
  |---|---|
  | `task.comment` | `commented on #12` |
  | `task.assigned` | `assigned {name or 'you'} to #12` |
  | `task.deleted` | `deleted #12` |
  | `task.created` | `created #12` |
  | `project.created` | `created {title}` |
  | `team.member.added` | `added {name or 'you'} to the {team} team` |
  | `task.reminder` | `Reminder for #12 {title} ({project})` |
  | `task.mentioned` | `{doer} mentioned you on #12` |

  Routes: task notifications open the task, `project.created` opens the project, `team.member.added` opens the team.
- **List view subtasks** (`frontend/src/composables/useTaskListFiltering.ts`) [T]: a task with `related_tasks.parenttask`
  is hidden from the flat list only if one of its parents is in the current result set. It is rendered nested under that parent instead.

---

## 8. Filter query language (client side)

### 8.1 Grammar as the web UI exposes it

From `frontend/src/helpers/filters.ts` and `frontend/src/components/input/filter/FilterInputDocs.vue` [V]:

- **Fields** (camelCase in the UI, converted to snake_case for the API):
  - `done`, `priority`, `percentDone`
  - `dueDate`, `startDate`, `endDate`, `doneAt`, `reminders`, `created`, `updated` (the date fields)
  - `assignees`, `createdBy`, `labels`, `project`
- **Operators**: `!=  =  >  >=  <  <=  like  in  not in  ?=`. `?!=` is only treated as multi-value. Word operators get `\b` boundaries.
- **Joins**: `&&`, `||` and parentheses.
- **Multi-value** (`in`, `not in`, `?=`, `?!=`): comma-separated values.
- **Values** may be quoted with `"` or `'`. Backslash escapes are allowed inside quotes.
- **Dates** accept datemath:
  - an anchor of `now` or `<date>||`
  - `+N<unit>`, `-N<unit>`, `/<unit>` rounding
  - units `s m h H d w M y`
  - examples: `now/d`, `now/w+1w`, `now+7d`, `2024-01-01||+1M/d`

  Non-datemath dates are parsed server-side as RFC3339, `YYYY-MM-DD HH:mm`, `YYYY-MM-DD` or `Y-M-D` in `filter_timezone`
  (`pkg/models/task_collection_filter.go` `parseTimeFromUserInput`).
- **Assignees and createdBy** are written as **usernames** and are not converted by the client. The autocomplete inserts `username`
  (`FilterAutocomplete.ts:388`).
- **Labels and project** are converted between titles (in the UI) and ids (on the wire).

### 8.2 `transformFilterStringForApi(filter, labelResolver, projectResolver)` [V][T]

1. `trim()`. If the result is empty, return `''`.
2. Case-normalise field names that are followed by an operator. `startdate > now` becomes `start_date > now` [T].
3. For `labels`, then `project`, use the regex
   `\b(field)\s*(op)\s*(?:(["'])((?:\\.|(?!\3)[^\\])*?)\3|([^&|()<]+?))(?=\s*(?:&&|\||\)|$))`:
   1. The keyword is the quoted or unquoted capture. For multi-value operators, split on `,` and trim quotes.
   2. Resolve each keyword with the resolver. If that gives null and the keyword contains `\`, retry without backslashes.
      Keep it unchanged if still unresolved.
   3. Join multi-value results with `', '`.
   4. **Strip all `"` and `'`** from the replacement.
   5. Rebuild the clause as `${field} ${op} ${value}`. This also normalises `labels=ipsum` to `labels = ipsum` [T].
   6. Replacements are position-based and collected before they are applied.
4. Convert field names followed by an operator to snake_case: `percentDone`→`percent_done`, `dueDate`→`due_date`,
   `doneAt`→`done_at`, `createdBy`→`created_by`, and so on.

**Resolvers**: label title → id via case-insensitive exact title over all labels (`getLabelByExactTitle`). Project title → id
via case-insensitive exact title over real projects (`findProjectByExactname`) (`FilterInput.vue:144`, `Filters.vue:153`).

**Golden examples** [T]:

- `labels = lorem && dueDate = now && labels = ipsum` → `labels = 1 && due_date = now && labels = 2`
- `labels in lorem, ipsum` → `labels in 1, 2`
- `labels not in …` behaves the same way
- `labels in ipsum || labels in l` → `labels in 2 || labels in l`
- `( labels = label || project = Filtertest )` → `( labels = 456 || project = 123 )`
- `labels = "John's Task"` → `labels = 1`
- `labels in "John's Task", Mary's` → `labels in 1, 2`
- `dueDate = now/d || dueDate > now/w+1w` → `due_date = now/d || due_date > now/w+1w`

### 8.3 `transformFilterStringFromApi(filter, labelIdToTitle, projectIdToTitle)` [V][T]

1. `replaceAll(snake, camel)` for every field. This is a plain substring replace.
2. Resolve label and project ids to titles. Titles are **not re-quoted**: `labels = John's Task`, `labels in lorem, ipsum`.
3. Unknown ids stay as they are. Ids appearing elsewhere (`priority = 1 && labels = 1`) are untouched thanks to position-based
   replacement [T].

### 8.4 Free text versus filter

`hasFilterQuery(s)` returns true if any operator substring occurs in `s`. In the filter popup
(`frontend/src/components/project/partials/Filters.vue`), input without an operator is sent as the search term **`s`**
(`q` on task lists) and `filter=''` [V].

### 8.5 Include nulls

The `filter_include_nulls` checkbox, "Show tasks which don't have a value set", is a separate boolean param [V].

### 8.6 Porting notes [I]

- Dart has `\b` and lookahead, so the regex ports. Note the backreference `\3` inside a negative lookahead: Dart supports it.
- Implement `snakeCase` for exactly these 14 field names; don't pull in a library.
- Server errors on an invalid filter come back as problem bodies (see the API research).

---

## 9. Task list queries per screen (exact params) [V]

Common to all of them: the web also sends `filter_timezone = settings.timezone` and paginates with `page`. `per_page` is omitted,
so the server default applies.

| Screen | Endpoint (v2 SDK) | sort_by / order_by | filter | include_nulls | expand | Source |
|---|---|---|---|---|---|---|
| Home "current tasks" (no date range) | `GET /tasks`, or the saved filter's pseudo project when `frontend_settings.filter_id_used_on_overview` is set and no `?labels=` | `['due_date','id']` / `['asc','desc']` | `done = false`, plus ` && labels in 1, 2` from `?labels=` | false | `['comment_count','is_unread']` | `frontend/src/views/tasks/ShowTasks.vue:262-300`, `views/Home.vue` |
| Upcoming `/tasks/by/upcoming` | `GET /tasks` | same | `done = false && due_date < '<to>'`, plus ` && due_date > '<from>'` unless `showOverdue` | `showNulls` | same | `ShowTasks.vue`; route defaults `from=new Date()` and `to=now+7d` as ISO (`frontend/src/router/index.ts:225`) |
| Upcoming with a preset | same | same | e.g. Today: `done = false && due_date < 'now/d+1d' && due_date > 'now/d'` [T] | | | `ShowTasks.test.ts`; presets in `frontend/src/components/date/dateRanges.ts` |
| Project List view | `GET /projects/{p}/views/{v}/tasks` | default `{position:'asc'}`, so `sort_by=['position']`, `order_by=['asc']`. `id` is moved last only if the user picked it. While searching (`q`) with no explicit sort, **no sort** is sent (relevance) | URL `?filter=`, else the view's own filter (server-side) | false | `['subtasks','comment_count','is_unread']` (Favorites -1: no subtasks) | `frontend/src/components/project/views/ProjectList.vue:154`, `frontend/src/composables/useTaskList.ts` |
| Table view | same endpoint | default `{index:'desc'}`, persisted in localStorage `tableViewSortBy`. Only columns that are visible are sent | same | | `['comment_count','is_unread']` | `ProjectTable.vue:403-420` |
| Gantt | `GET /projects/{p}/views/{v}/tasks` (all pages) | `['start_date','done','id']` / `['asc','asc','desc']` | `((start_date >= "F" && start_date <= "T") \|\| (end_date >= "F" && end_date <= "T") \|\| (due_date >= "F" && due_date <= "T") \|\| (start_date <= "F" && end_date >= "T"))` with F/T as `YYYY-MM-DD`. Default range today−15d … today+55d | `showTasksWithoutDates` | `['subtasks']` | `frontend/src/views/project/helpers/useGanttFilters.ts:83` |
| Kanban | `GET /projects/{p}/views/{v}/buckets/tasks` | `[]` | URL filter | false | `['comment_count','is_unread']`, `per_page=25` per bucket, more pages per bucket on scroll | `frontend/src/client/queries/kanban.ts`, `ProjectKanban.vue:402` |
| Generic default | | `['position','id']` / `['asc','desc']` | `''` | false | `['subtasks']` | `frontend/src/client/queries/tasks.ts` `getDefaultTaskFilterParams` |
| New saved filter / new project view draft | | `['done','id']` / `['asc','desc']` | `done = false` | **true** | | `frontend/src/client/queries/savedFilters.ts:47`, `projectViews.ts:40` |
| Server default List view for new projects | | | `done = false` | | | `pkg/models/project_view.go:825`. Positions 100/200/300/400 for List/Gantt/Table/Kanban |

Notes:

- **Show done**: there is no separate flag any more. "Show done tasks" means removing `done = false` from the filter. The view
  filter is applied server-side and combined with the request filter (`Filters.vue` shows "filter from view").
- **Pseudo projects** (`frontend/src/client/queries/projects.ts:219`):
  - `-1` is Favorites.
  - A saved filter `id` maps to project id `-(id+1)` (`getProjectIdFromSavedFilterId`).
  - The reverse is `max(0, -pid-1)`.
  - They appear only in the project list, never under `/projects/{id}`.
- **Default view on project open** (`frontend/src/views/project/ProjectView.vue:52`):
  - Use the last view for that project from localStorage `projectView`, a `{projectId: viewId}` map.
  - Else the first view whose `view_kind` equals `frontend_settings.default_view`, unless that is `'first'`.
  - Else the first view by position.
- **Per-view query memory**: `stores/viewFilters.ts` stores `{sort, filter, s, page}` per view id in localStorage and restores it
  when the URL is empty (`useTaskList.ts:138`).
- **Paging helpers**: `fetchAllPages` loops while `page < total_pages` (`frontend/src/client/queries/fetchAllPages.ts`).
  Labels, the project list and Gantt fetch all pages.

---

## 10. Position and ordering math [V][T]

`frontend/src/helpers/calculateItemPosition.ts` is used for tasks (List, Kanban), buckets, projects (sidebar) and views:

```
MIN_POSITION_SPACING = 0.01            // equals backend MinPositionSpacing (pkg/models/task_position.go:38)
calc(before, after):
  if before != null && after != null && before == after: return after + 0.01
  if before == null: return after == null ? 0 : after / 2
  if after == null: return before + 65536           // 2^16
  return before + (after - before) / 2
```

Tests (`calculateTaskPosition.test.ts`):

| Input | Output |
|---|---|
| `(10,100)` | 55 |
| `(null,null)` | 0 |
| `(null,100)` | 50 |
| `(10,null)` | 65546 |
| `(100,100)` | in (100,101) |
| `(0,0)` | > 0 |

- **List drag**:
  - Allowed only when sorting by position and the user can write (or the project is a saved filter).
  - The neighbours come from the reordered displayed list.
  - The client calls `PUT /tasks/{id}/position {position, project_view_id}`, then re-sorts the cached lists by position in the
    sort direction (`taskMutations.ts` `updateTaskPositionMutationOptions`).
- **Kanban drag** (`ProjectKanban.vue:560`):
  1. If the bucket changed, call `taskBucketUpdate`: `PUT /projects/{p}/views/{v}/buckets/{b}/tasks {task_id}`. If the server
     answers with a different `bucket_id`, stop (e.g. a limit or done-bucket redirect).
  2. Then set the position from the neighbours in the target bucket.
  3. If the card was dropped at index 0 and the next card has position 0, also move that next card to `calc(0, nextNext)`.
- **Bucket reorder**: `calc(bucketBefore.position, bucketAfter.position)` → `PUT /projects/{p}/views/{v}/buckets/{b}` with `{title, limit, position}` (`ProjectKanban.vue:500-509`, sdk `bucketsUpdate`).
- **Bucket limit**:
  - Dropping is refused when `limit > 0 && count >= limit`, unless the card comes from the same bucket.
  - The badge shows `count/limit`, or `count` when `always_show_bucket_task_count` is set.
  - The add-task input closes once the limit is reached.
  - A limit is entered as an integer ≥ 0, debounced 2.5 s.
- **Done bucket**: marking done moves the card into `view.done_bucket_id`. Un-marking a task that sits in the done bucket moves it
  to `default_bucket_id`, or the first bucket (`taskMutations.ts` `reconcileDoneBuckets`, `getDefaultBucketId` in `helpers/task.ts`).
  The server does the same thing authoritatively.
- **Project reorder** (`frontend/src/components/home/ProjectsNavigation.vue:95`):
  - Neighbours come from the sibling list.
  - `parent_project_id` is the new parent container's id. A project that is orphaned (its parent is not visible) keeps its parent.
  - Safari's "index == length" is clamped.
- **View reorder**: `ProjectSettingsViews.vue:145`.
- **Bulk insert order**: new tasks appear at the top. The client inserts back to front.

---

## 11. Marking done and undo (List/Kanban) [V]

`frontend/src/components/tasks/partials/SingleTaskInProject.vue` `markAsDone`:

1. Snapshot `oldTask`, then immediately `PATCH` with `done: checked`.
2. When checking, wait 300 ms (animation) before handling the result. Unchecking has no delay.
3. Play the pop sound if `frontend_settings.play_sound_when_done`.
4. Toast "The task was successfully marked as done." with an **Undo** action. For a non-repeating task that was un-done,
   the message is "…un-marked as done."
5. **Undo** of a repeating task re-sends the **pre-completion snapshot** (old dates) with `done:false`, which restores the dates.
   For a non-repeating task it just toggles `done`.

`KanbanCard.vue` emits `taskCompletedRecurring` when a repeating task was completed.

The task detail (`TaskDetailView.vue:1175`) toggles `done` and plays the sound.

Porting [I]: the notification "mark done" action should send `done:true` and update the local cache from the response. A
repeating task comes back `done:false` with shifted dates, so reschedule its notifications from the response.

---

## 12. Saving a task (write body rules) [V]

`frontend/src/client/queries/taskMutations.ts`:

- **Writable fields**: `title`, `description`, `done`, `due_date`, `start_date`, `end_date`, `priority`, `hex_color`,
  `percent_done`, `repeat_after`, `repeat_mode`, `is_favorite`, `bucket_id`, `project_id`, `reminders`,
  `cover_image_attachment_id`. Fields that are `undefined` are omitted.
- The title is trimmed and `hex_color` loses its `#`.
- Empty dates and empty reminder dates become `0001-01-01T00:00:00Z`.
- **Update**: v2 `PATCH /tasks/{id}` with `Content-Type: application/json-patch+json`. The body is
  `[{op:'add', path:'/<field>', value}]` for every present writable field (sdk `patchTasksRead`).
- **Create**: `POST /projects/{project}/tasks`. Labels and assignees are separate endpoints.
- **Favorite**: PATCH `[{op:'add',path:'/is_favorite',value:!fav}]`, then refetch the project list (Favorites pseudo project).
- **Merge rule** (`mergeTask`): view-specific `position` and `bucket_id` from the cache win, because write responses carry no
  view context. `assignees`, `labels`, `attachments`, `related_tasks`, `reactions` and `created_by` from the response win only
  when they are present [T].
- **Task detail save rule** (`TaskDetailView.vue:1138`): if `end_date` is empty but **both** `start_date` and `due_date` are set,
  `end_date = due_date` is sent.

---

## 13. Descriptions and comments: HTML conventions [V]

- **Storage format.** Descriptions and comments are **HTML** produced by TipTap (`frontend/src/components/input/editor/TipTap.vue`,
  `editorExtensions.ts`). The server comment: "descriptions are always stored as HTML, never markdown"
  (`pkg/models/tasks.go` `resetDescriptionChecklist`). Extensions in use:
  - StarterKit, with codeBlock replaced by CodeBlockLowlight
  - Link (`target=_blank rel="noopener noreferrer nofollow"`)
  - Table, Typography, Image (custom), Subscript, Superscript, Underline, HardBreak
  - TaskList and TaskItemWithId
  - blockquote with comment id, emoji, commands
  - Mention (only when enabled and a projectId is set)
- **Checklist items.** TipTap renders `<ul data-type="taskList"><li data-checked="true|false" data-type="taskItem"
  data-task-id="<nanoid 8>">…`. The web generates `data-task-id` and de-duplicates it so the checkbox state persists
  (`taskItemWithId.ts`). A mobile editor must emit the same markup, or at least `data-checked`, for progress and the server-side
  reset to work.
- **Mentions.** Serialized as `<mention-user data-id="<username>" data-label="<display name>">`.
  - The server extracts usernames from `mention-user[data-id]` to send `task.mentioned` notifications
    (`pkg/models/mentions.go` `extractMentionedUsernames`).
  - The suggestions query `GET /projects/{id}/users/search?q=` with a 300 ms debounce, and show 10 results (5 when the query is empty).
  - Each suggestion is `{id: username, label: getDisplayName(user)}` (`mention/mentionSuggestion.ts`).
- **Task links.** A plain `<a href>` whose text equals its href and whose path is `<frontendBase>/tasks/<id>` is rendered as a
  task pill. It is stored as a normal anchor (`taskLink.ts`).
  - Accepted bases: the current origin, or `/info`'s `frontend_url`. The id must match `^\d+$` and be > 0
    (`frontend/src/helpers/parseTaskIdFromUrl.ts`, with tests).
  - Rejected forms include `/tasks/12/edit`, `/tasks/0`, `/tasks/by/upcoming`, look-alike hosts, and a missing base path.
  - Mobile [I]: treat such links as deep links into the app.
- **Inline images.** Images uploaded from the editor become task attachments and are referenced as
  `<img src="{apiRoot}/api/v2/tasks/{taskId}/attachments/{attachmentId}">`. Older ones use `/api/v1/…`.
  - The parse regex is `^(.*?)(?:\/api\/v[12])?\/tasks\/(\d+)\/attachments\/(\d+)$`, and the prefix must equal the configured API root.
  - Such images are **fetched as an authenticated blob** and swapped in. Stored `id` attributes are ignored for safety
    (`editorExtensions.ts:44-200`).
- **Markdown.** Only when pasting: plain text containing any of `* \` _ [ ] # -` and no rich HTML on the clipboard is converted
  with `marked` (`editorExtensions.ts:240-275`). Legacy markdown descriptions are not converted on display [I: no converter found].
- **Sanitising.** Only the project description view uses DOMPurify (`frontend/src/views/project/ProjectInfo.vue:30-61`, with
  `target` added). Task descriptions are rendered by TipTap/ProseMirror, which only keeps schema nodes, so arbitrary HTML is dropped.
  - Porting [I]: render with an HTML-to-widget renderer that allow-lists the same node types. Never run scripts. Route `<img>`
    attachment URLs through the authenticated fetch.
- **Drafts.** Unsaved editor content is kept in localStorage per `storageKey` (`frontend/src/helpers/editorDraftStorage.ts`).
- **Comments.** The sort order comes from `frontend_settings.comment_sort_order` (`'asc'` by default).

---

## 14. Avatars, attachments, backgrounds: authenticated binary fetching [V]

All binary resources are fetched **through the authenticated client as blobs** (with a bearer header), never via `<img src=url>`
with cookies.

- **Avatar.**
  - Request: `GET {api}/avatar/{username}?size={n}` (sdk `avatarGet`, `parseAs:'blob'`). The default `size` is 50 (`UserAvatar.vue`).
  - Cached forever per (username, size) and invalidated when the avatar provider or upload changes (`client/queries/avatars.ts`).
  - SVG responses (`image/svg+xml`) are converted to a `data:` URL instead of a blob URL so they cannot script.
  - Set the provider with `PUT /user/settings/avatar/provider {avatar_provider}`. Upload with `PUT /user/settings/avatar` (multipart `avatar`, file named `avatar.png`).
  - The initials avatar changes with the name, so it is refetched after a name change when the provider is `initials` (`account.ts`).
- **Attachments.**
  - Download: `GET /tasks/{task}/attachments/{attachment}[?preview_size=sm|md|lg|xl]`. Previews are downscaled PNGs of 100,
    200, 400 or 800 px, and only for image mimes (`pkg/routes/api/v2/task_attachments.go:169`).
  - The web uses `md` for the attachment list preview (`FilePreview.vue:91`) and `lg` for Kanban cover images (`KanbanCard.vue:241`).
  - Image preview requires the name suffix `.jpeg .jpg .png .bmp .gif` **and** a sniffed mime `image/*` other than svg.
    PDF requires `.pdf` and `application/pdf`. Audio and video are allowed by mime prefix (`frontend/src/helpers/attachmentPreview.ts`, tested).
  - The cover image is `task.cover_image_attachment_id`. It only shows if that attachment has an image suffix.
  - Upload: multipart `files` field to `/tasks/{id}/attachments`. The response carries `success[]` (and errors) (`client/queries/attachments.ts`).
  - Deleting the cover attachment resets `cover_image_attachment_id` to 0 locally.
- **Project background.**
  - Fetched only if `project.background_information` is set: `GET /projects/{id}/background` as a blob.
  - While it loads, a **blurhash** placeholder is decoded from `project.background_blur_hash` at **32×32** (`helpers/getBlobFromBlurHash.ts`).
  - Unsplash thumbnails: `GET /backgrounds/unsplash/images/{id}/thumb` as a blob. Search: `GET /backgrounds/unsplash/search?q=&page=`
    (`client/queries/projectBackgrounds.ts`).
  - Brightness: see section 6.
- **API URL discovery** (`frontend/src/helpers/checkAndSetApiUrl.ts`, `apiUrl.ts`) [T]:
  - Normalise: strip trailing `/` and a trailing `/api/v1` or `/api/v2`. Default the scheme to the page scheme.
  - Probe `GET {root}/api/v2/info`. On failure, retry the same host on port **3456**.
  - Example: `https://new.example.com/root/api/v1` is accepted as `https://new.example.com:3456/root` when only that port answers [T].

---

## 15. Live updates the web relies on (for background sync design) [V]

- The WebSocket is `wss://…/api/v2/ws`:
  - The client sends `{action:'auth', token}`, receives `{action:'auth.success', success:true}`, then sends
    `{action:'subscribe', event}` / `{action:'unsubscribe', event}`.
  - `invalid_token` and `auth_required` errors are terminal.
  - Reconnects use backoff `min(1s·2^n, 30s)` with ±25% jitter. The client re-authenticates after a token refresh
    (`frontend/src/composables/useWebSocket.ts`).
- **Only** these events exist client-side: `timer.created|updated|deleted` (time tracking) and `notification.created`
  (`frontend/src/client/queries/serverEvents.ts` `CACHE_EVENTS`).
  - There are **no task create/update events**: the web refreshes task lists by refetching (5-minute stale time for projects and labels).
  - After (re)subscribing, it invalidates queries last fetched before the subscribe time.
  - Implication [I]: the mobile client must poll for task changes (e.g. `updated > <last sync>` filters) to show web-created tasks.
    `notification.created` can trigger an immediate refresh.

---

## 16. User settings shared with the web [V]

- `GET /user` returns `settings` (`pkg/models/user_settings.go` `UserGeneralSettings`):
  - `name`, `email_reminders_enabled`, `discoverable_by_name`, `discoverable_by_email`
  - `overdue_tasks_reminders_enabled`, `overdue_tasks_reminders_time` (`HH:MM`)
  - `default_project_id`, `week_start`, `language`, `timezone`
  - `frontend_settings` (an arbitrary JSON blob stored verbatim)
  - `extra_settings_links` (read-only)
- **`frontend_settings` keys and defaults** (`frontend/src/helpers/userSettings.ts`):

  | key | default |
  |---|---|
  | `play_sound_when_done` | true |
  | `quick_add_magic_mode` | `'vikunja'` |
  | `color_schema` | `'auto'` (also `light` or `dark`) |
  | `allow_icon_changes` | true |
  | `filter_id_used_on_overview` | null |
  | `default_view` | `'first'` (also `list`, `gantt`, `table` or `kanban`) |
  | `minimum_priority` | 2 |
  | `date_display` | `'relative'` |
  | `time_format` | `'24h'` |
  | `default_task_relation_type` | `'related'` |
  | `background_brightness` | null |
  | `always_show_bucket_task_count` | false |
  | `show_last_viewed` | true |
  | `sidebar_width` | null |
  | `comment_sort_order` | `'asc'` |
  | `desktop_quick_entry_shortcut` | `'CmdOrCtrl+Shift+A'` |
  | `default_due_time` | undefined (`HH:MM`) |
  | `time_tracking_default_start` | `'09:00'` |
  | `quick_add_default_reminders` | `[]` |

  On read, the client applies `{...defaults, ...server}` (`client/queries/account.ts` `normalizeUserSettings`). Other server
  defaults: `email_reminders_enabled` true, `overdue_tasks_reminders_enabled` true, time `'09:00'`, `week_start` 0, and
  `language` falls back to the browser language.
- **Saving**: `PATCH /user/settings/general` with `Content-Type: application/merge-patch+json` and **only the changed keys**, including
  only the changed `frontend_settings` keys. That way keys a mobile app doesn't know (or adds, e.g. a `mobile_*` namespace) survive.
  An empty **304** means "no change" and is not an error (`account.ts:206-225`).
- **Porting**: always merge-patch. Never PUT the whole `frontend_settings`.

---

## 17. i18n [V]

- **Enabled UI locales** (`frontend/src/i18n/index.ts` `SUPPORTED_LOCALES`, 32):
  - `en`, `de-DE`, `de-swiss`, `ru-RU`, `fr-FR`, `vi-VN`, `it-IT`, `cs-CZ`
  - `pl-PL`, `nl-NL`, `pt-PT`, `zh-CN`, `zh-TW`, `no-NO`, `es-ES`, `da-DK`
  - `ja-JP`, `hu-HU`, `ar-SA`, `fa-IR`, `sl-SI`, `pt-BR`, `hr-HR`, `uk-UA`
  - `lt-LT`, `bg-BG`, `ko-KR`, `tr-TR`, `fi-FI`, `he-IL`, `sv-SE`, `el-GR`
- Files that exist but are **not enabled**: `ca-ES`, `eo-UY`, `ro-RO`, `sk-SK`, `sr-CS`, `th-TH` (`frontend/src/i18n/lang/`).
- The backend allow-list (`pkg/i18n/i18n.go:50-80`) has 31 entries: the same list **without `fa-IR`**.
- RTL locales: `ar-SA`, `he-IL`, `fa-IR`.
- **Fallback**: `en`. Browser language matching: an exact key match, or a key starting with `navigator.language + '-'`.
- **Message format** (vue-i18n): `{name}` and `{0}` placeholders, and pipe plurals like `"minute|minutes"` (16 in `en.json`).
  There are no `@:` linked messages. `ru-RU` has a custom 3-form plural rule (`index.ts:62`).
  - `en.json` is 1808 lines. Porting [I]: convert to ARB at build time, translating `a|b` into ICU plurals, or write a small runtime
    for the vue-i18n format so translations can be synced from upstream.
- **Day.js locale mapping**, used for relative and long date formats (`useDayjsLanguageSync.ts`):
  - `de-swiss→de-ch`, `no-NO→nb`, `pt-BR→pt`, `ar-SA→ar-sa`
  - `zh-CN→zh-cn`, `zh-TW→zh-tw`
  - otherwise the language part
  - In Dart, use `intl` with the equivalent locales.
- The quick-add grammar is English-only (1.8). Notification strings in `helpers/notification.ts` are English-only (7).

---

## 18. Web-local state the mobile app may want to mirror [V]

The web keeps the following in localStorage, not on the server:

- `projectHistory`: the last 6 visited projects, most recent first, de-duplicated (`frontend/src/modules/projectHistory.ts`, tested).
  Shown on Home when `show_last_viewed`.
- `projectView`: last view per project.
- `collapsedBuckets`: `{projectId: {bucketId: true}}`.
- `tableViewColumns` / `tableViewSortBy`.
- Per-view query (`stores/viewFilters.ts`).
- `navigation-child-projects-open`.
- `API_URL`, `token`, `serverClockOffset`.
- Clock skew: `serverClockOffset = iat*1000 - Date.now()`, measured at token issue time. Token expiry is checked against server
  time (`frontend/src/helpers/serverClock.ts`, `auth.ts:50`).

---

## 19. Test files worth translating into Dart

Priority A covers pure logic that must behave identically:

| Test file | What it pins |
|---|---|
| `frontend/src/modules/quickAddMagic/quickAddMagic.test.ts` | the whole quick-add grammar (about 600 generated cases) |
| `frontend/src/helpers/task.test.ts` | `createTaskDraft`, `createReminderDraft`, `getTaskIdentifier`, `getHexColor`, repeat conversion, `mergeTask`, `mapTasksDeep`/`removeTask`, `moveTaskToBucket`, `getDefaultBucketId`, default reminders, `buildQuickAddTask` |
| `frontend/src/composables/useQuickAddTask.test.ts` | the create flow against a mocked SDK (assignee strip, label failure, magic-only) |
| `frontend/src/helpers/parseSubtasksViaIndention.test.ts` | multi-line/subtask parsing |
| `frontend/src/helpers/filters.test.ts` | filter title↔id transforms |
| `frontend/src/components/input/filter/FilterAutocomplete.test.ts`, `highlighter.test.ts` | autocomplete replacement range and token classes (if you build the same filter editor) |
| `frontend/src/helpers/calculateTaskPosition.test.ts` | position math |
| `frontend/src/helpers/checklistFromText.test.ts` | checklist counting |
| `frontend/src/helpers/color/colorFromHex.test.ts`, `colorIsDark.test.ts`, `getTextColor.test.ts` | colors and contrast |
| `frontend/src/helpers/parseDateOrNull.test.ts` and `frontend/src/helpers/time/toISOStringOrNull.test.ts` | zero-date handling |
| `frontend/src/helpers/time/calculateDayInterval.test.ts`, `calculateNearestTime.test.ts`, `getDateWithTime.test.ts`, `dateShortcuts.test.ts`, `calendarGrid.test.ts`, `dateMath.test.ts`, `createDateFromString.test.ts`, `formatDate.test.ts`, `roundToNaturalDayBoundary.test.ts`, `smartFillStart.test.ts` | date helpers |
| `frontend/src/views/tasks/ShowTasks.test.ts` | the exact Upcoming filter strings |
| `frontend/src/views/project/helpers/useGanttFilters.test.ts` | Gantt default ranges and route parsing |
| `frontend/src/composables/useTaskListFiltering.test.ts` | subtask hiding in lists |
| `frontend/src/helpers/parseTaskIdFromUrl.test.ts` | task deep-link recognition |
| `frontend/src/helpers/attachmentPreview.test.ts`, `attachments.test.ts` | preview gating |
| `frontend/src/helpers/notification.test.ts` | notification text and routes |
| `frontend/src/helpers/user.test.ts` | display name |

Priority B (useful):

- `frontend/src/helpers/apiUrl.test.ts`, `checkAndSetApiUrl.test.ts` (server URL normalisation and the 3456 fallback)
- `frontend/src/helpers/parseValidationErrors.test.ts` (Huma `errors[].location` `body.x` and legacy `invalid_fields: ['field: msg']`)
- `frontend/src/modules/projectHistory.test.ts`
- `frontend/src/stores/viewFilters.test.ts`
- `frontend/src/helpers/hourToDaytime.test.ts`, `stringHash.test.ts`, `composables/useDaytimeSalutation.test.ts`
- `frontend/src/client/queries/pagination.test.ts`, `fetchAllPages.test.ts`
- `frontend/src/client/queries/serverEvents.test.ts` (WS event parsing)
- `frontend/src/helpers/apiToken.test.ts`, `parseScopesFromQuery.test.ts` (`"group:perm,group:perm"`)
- `frontend/src/helpers/auth.test.ts`, `stores/auth.clockSkew.test.ts` (token expiry with clock offset)
- Gantt only: `frontend/src/helpers/ganttTaskTree.spec.ts`, `ganttRelationArrows.spec.ts`
- Editor only: `frontend/src/components/input/editor/taskItemWithId.test.ts`, `taskLink.test.ts`, `markdownPaste.test.ts`

---

## 20. Quirk register: decide whether to replicate or fix

| # | Behaviour | Where | Evidence |
|---|---|---|---|
| 1 | Quick-add `every N months` (N≠1), `every year`, `yearly`, `biannually` and so on produce **no repeat** (`repeat_after=0`, mode 0) | `helpers/time/period.ts` `periodToSeconds`, `helpers/task.ts` | [V] |
| 2 | `Every Day` and `Daily` (capitalised) parse as every 1 **hour** | `repeatParser.ts` case-sensitive switch | [V][P] |
| 3 | `today`, `tomorrow` and `next week` lack a trailing word boundary: `todays` and `next weekend` mis-parse | `dateParser.ts` `matchesDateExpr` | [P] |
| 4 | `<n> <mon>` / `<mon> <n>` match anywhere, e.g. `12 decorations` | `dateParser.ts` `getDateFromText` step 2 | [P] |
| 5 | Ordinal plus month can yield a past date. Ordinals and weekdays keep the current time-of-day (including seconds) | `dateParser.ts` | [P][T] |
| 6 | `next monday` on a Monday means today | `calculateDayInterval.ts` | [T] |
| 7 | After 21:00 the default time is 09:00 **today**, so it is in the past | `calculateNearestHours.ts` | [V][T] |
| 8 | Quick-actions search builds `' project = X' + 'labels in …'` without `&&` | `QuickActions.vue` | [V] |
| 9 | The reminder period editor never restores the "after" sign | `ReminderPeriod.vue` | [V] |
| 10 | `minimum_priority: 0` falls back to 2 | `PriorityLabel.vue` | [V] |
| 11 | The multi-line add pre-creates labels even for magic-only lines | `AddTask.vue` | [I] |
| 12 | Time entries use the device timezone, while task lists use `settings.timezone` | `useTimeTracking.ts` vs `useTaskList.ts` | [V] |
| 13 | `fa-IR` is a UI locale but is missing from the backend language allow-list | `pkg/i18n/i18n.go` | [V] |
