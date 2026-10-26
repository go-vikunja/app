import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/label_repository.dart';
import 'package:vikunja_mobile/core/text/html_to_text.dart';

/// With more labels than this, the labels page offers a search field.
const labelSearchThreshold = 12;

/// [labels] split into the user's own and the others' (the labels the user
/// sees on shared tasks), each in the given order.
({List<Label> own, List<Label> others}) groupLabels(
  List<Label> labels, {
  required int? userId,
}) {
  final own = <Label>[];
  final others = <Label>[];
  for (final label in labels) {
    (isOwnLabel(label, userId) ? own : others).add(label);
  }
  return (own: own, others: others);
}

/// The first line of text in a label's HTML description, empty without one.
String descriptionFirstLine(String html) {
  if (html.trim().isEmpty) return '';
  for (final line in htmlToPlainText(html).split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

final _shortHex = RegExp(r'^[0-9a-fA-F]{3}$');
final _longHex = RegExp(r'^[0-9a-fA-F]{6}$');

/// Six lower-case hex digits from three or six typed ones, with or without
/// `#`; null for anything else. The server would store three digits as
/// they are, which other clients read differently.
String? normalizedHexColor(String input) {
  var digits = input.trim();
  if (digits.startsWith('#')) digits = digits.substring(1);
  if (_longHex.hasMatch(digits)) return digits.toLowerCase();
  if (_shortHex.hasMatch(digits)) {
    return [for (final digit in digits.split('')) '$digit$digit']
        .join()
        .toLowerCase();
  }
  return null;
}
