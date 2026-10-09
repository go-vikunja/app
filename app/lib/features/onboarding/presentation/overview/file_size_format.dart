import 'package:intl/intl.dart';

const int _bytesPerMebibyte = 1 << 20;
const _units = ['MB', 'GB', 'TB'];

// Binary multiples labelled MB/GB/TB, as in the Vikunja web frontend.
String formatFileSize(int bytes, String locale) {
  var size = bytes / _bytesPerMebibyte;
  var unit = 0;
  while (size >= 1024 && unit < _units.length - 1) {
    size /= 1024;
    unit++;
  }
  final number = NumberFormat.decimalPattern(locale)..maximumFractionDigits = 1;
  return '${number.format(size)} ${_units[unit]}';
}
