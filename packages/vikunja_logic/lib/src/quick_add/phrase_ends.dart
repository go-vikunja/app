/// Where a date word ends, as a regular expression to append. QA-3: the
/// web has no trailing boundary, so `todays` was today and `next weekend`
/// next week; QA-4: an apostrophe followed by a letter does not end the
/// word either, so `today's` stays text, also where a `today` elsewhere is
/// removed.
const quickAddWordEnd = "(?!\\w|['\u2019]\\w)";

/// Where a time after `at` or `@` ends, as a regular expression to append.
/// QA-14: a time is read and removed only where it ends there, not out of
/// `at 221B`, `at 22:5` or, for `at 9`, `at 9 pm`.
const quickAddTimeEnd = r'(?![\w:]| ?[ap]m(?![\w:]))';
