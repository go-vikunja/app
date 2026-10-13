/// Null when the test process runs in Europe/Berlin's rules (CET/CEST,
/// switching on 2026-03-29 and 2026-10-25), else the reason to skip the
/// tests that need a DST change: Dart only knows the process's zone.
final String? needsBerlin =
    DateTime(2026, 3, 28, 12).timeZoneOffset == const Duration(hours: 1) &&
        DateTime(2026, 3, 29, 12).timeZoneOffset == const Duration(hours: 2) &&
        DateTime(2026, 10, 25, 12).timeZoneOffset == const Duration(hours: 1)
    ? null
    : 'needs TZ=Europe/Berlin';
