import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/text/title_order.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_view_labels.dart';

import '../../helpers/pump_app.dart';

void main() {
  test('labels with an umlaut sort among their base letter', () {
    expect(
      orderedByLabel(const ['Zahlung', 'Ärger', 'apfel'], (label) => label),
      ['apfel', 'Ärger', 'Zahlung'],
    );
  });

  for (final (name, l10n) in [('English', en), ('German', de)]) {
    test('the sort menu in $name: manual first, the rest by its labels', () {
      final menu = sortsInMenuOrder(l10n);
      final labels = [for (final sort in menu.skip(1)) sortLabel(l10n, sort)];

      expect(menu.first, TaskListSort.manual);
      expect(menu, unorderedEquals(TaskListSort.values));
      expect(labels, [...labels]..sort(compareTitles));
    });
  }
}
