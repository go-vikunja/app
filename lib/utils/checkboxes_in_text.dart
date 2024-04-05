class CheckboxStatistics {
  final int total;
  final int checked;

  const CheckboxStatistics({
    required this.total,
    required this.checked,
  });
}

class MatchedCheckboxes {
  final Iterable<Match> checked;
  final Iterable<Match> unchecked;

  const MatchedCheckboxes({
    required this.checked,
    required this.unchecked,
  });
}

MatchedCheckboxes getCheckboxesInText(String text) {
  const checkedString = '[x]';
  final checked = <Match>[];
  final unchecked = <Match>[];

  final matches = RegExp(r'[*-] \[[ x]]').allMatches(text);

  for (final match in matches) {
    if (match[0]?.endsWith(checkedString) ?? false)
      checked.add(match);
    else
      unchecked.add(match);
  }

  return MatchedCheckboxes(
    checked: checked,
    unchecked: unchecked,
  );
}

CheckboxStatistics getCheckboxStatistics(String text) {
  final checkboxes = getCheckboxesInText(text);

  return CheckboxStatistics(
    total: checkboxes.checked.length + checkboxes.unchecked.length,
    checked: checkboxes.checked.length,
  );
}
