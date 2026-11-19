import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/features/filters/application/filter_check.dart';

import '../../helpers/sample_data.dart';

void main() {
  test('a label created here and not on the server yet is never sent by its '
      'temporary id; its title stays as typed', () {
    final lookups = FilterLookups(
      labels: const [
        Label(id: 3, title: 'Work'),
        Label(id: -1, title: 'Errand'),
      ],
    );

    final api = lookups.toApi('labels in Work, Errand');

    expect(api, contains('3'));
    expect(api, contains('Errand'));
    expect(api, isNot(contains('-1')));
  });

  test('a negative id is never kept as one: no label or project the server '
      'has goes by it', () {
    final lookups = FilterLookups(
      labels: const [Label(id: 7, title: '-1')],
      projects: [sampleProject(id: 8, title: '-2')],
    );

    final api = lookups.toApi(
      'labels in -1 && project = -2',
      keepIds: const FilterIds(labels: {-1}, projects: {-2}),
    );

    expect(api, 'labels in 7 && project = 8');
  });
}
