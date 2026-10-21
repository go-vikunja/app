import 'package:intl/intl.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

/// [bytes] the way the web writes sizes, with the locale's decimal sign.
String formatFileSize(AppLocalizations l10n, int bytes) => humanSize(
  bytes,
  formatNumber: NumberFormat.decimalPattern(l10n.localeName).format,
);
