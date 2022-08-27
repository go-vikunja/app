extension StringExtensions on String {
  Uri? toUri() => Uri.tryParse(this);
}
