import 'package:intl/intl.dart';

extension DateExtensions on DateTime {
  String formatShort([String? locale]) {
    return dateFormatShort().format(this);
  }
}

DateFormat dateFormatShort([String? locale]) {
  return DateFormat.yMMMd(locale).add_Hm();
}
