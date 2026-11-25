/// A character that continues a word: a letter, digit or mark of any
/// alphabet, or `_`. Only for a regular expression made with
/// `unicode: true`; without it `\p{L}` is read as the letters `p{L}`.
const quickAddWordCharacter = r'[\p{L}\p{N}\p{M}_]';

/// Where a date word ends, as a regular expression to append to one made
/// with `unicode: true`. QA-3: the web has no trailing boundary, so
/// `todays` was today and `next weekend` next week; QA-4: an apostrophe
/// followed by a letter does not end the word either, so `today's` stays
/// text, also where a `today` elsewhere is removed. A letter outside A to
/// Z continues the word too: `3 março` holds no `3 mar`.
const quickAddWordEnd =
    "(?!$quickAddWordCharacter|['\u2019]$quickAddWordCharacter)";

/// Where the web lets a weekday or a repeat word end, as a regular
/// expression to append: at a space or the end.
const quickAddSpaceEnd = r'(?=$| )';

/// Where a weekday or a repeat word may also end, tried only where the
/// web's rules found nothing, as a regular expression to append. QA-6:
/// at punctuation followed by whitespace or the end, so `Call Bob friday.`
/// has a date, while a word joined on (`mon-fri`, `sat/sun`) keeps it
/// text; a closing quote ends none, as it may close a quoted name
/// (`@"Team sat"`).
const quickAddPunctuationEnd = '(?=[.,;:!?\u2026)\\]}]+(?!\\S))';

/// Where a removed weekday ends: either of [quickAddSpaceEnd] and
/// [quickAddPunctuationEnd], so `mon-fri` keeps its `mon` when another
/// `mon` is the date.
const quickAddSpaceOrPunctuationEnd =
    '(?:$quickAddSpaceEnd|$quickAddPunctuationEnd)';

/// Where a time after `at` or `@` ends, as a regular expression to append.
/// QA-14: a time is read and removed only where it ends there, not out of
/// `at 221B`, `at 22:5` or, for `at 9`, `at 9 pm`.
const quickAddTimeEnd = r'(?![\w:]| ?[ap]m(?![\w:]))';
