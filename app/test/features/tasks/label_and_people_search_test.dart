import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/tasks/application/color_palette.dart';
import 'package:vikunja_mobile/features/tasks/application/label_search.dart';
import 'package:vikunja_mobile/features/tasks/application/people_search.dart';

import '../../helpers/sample_data.dart';
import '../../helpers/zero_random.dart';

void main() {
  group('labels', () {
    final labels = [
      sampleLabel(id: 1, title: 'Errand'),
      sampleLabel(id: 2, title: 'Garden'),
      sampleLabel(id: 3, title: 'Gardening tools'),
    ];

    test('filter by substring, ignoring case and outer spaces', () {
      expect(filterLabels(labels, ' GARD '), [labels[1], labels[2]]);
      expect(filterLabels(labels, 'rr'), [labels[0]]);
      expect(filterLabels(labels, ''), labels);
      expect(filterLabels(labels, 'x'), isEmpty);
    });

    test('filter ignoring accents, in the query too', () {
      final cafe = sampleLabel(id: 4, title: 'Café');
      final decomposed = sampleLabel(id: 5, title: 'Cafe\u0301 noir');

      expect(filterLabels([...labels, cafe, decomposed], 'cafe'), [
        cafe,
        decomposed,
      ]);
      expect(filterLabels([...labels, cafe, decomposed], 'CAFÉ N'), [
        decomposed,
      ]);
      expect(filterLabels([...labels, cafe], 'Gärden'), [labels[1], labels[2]]);
    });

    test('offer to create the trimmed query unless a title matches '
        'exactly', () {
      expect(labelTitleToCreate(labels, ' Gard '), 'Gard');
      expect(labelTitleToCreate(labels, 'garden'), isNull);
      expect(labelTitleToCreate(labels, '   '), isNull);
      expect(labelTitleToCreate(const [], 'New'), 'New');
    });

    test('a title differing only in accents is still offered', () {
      final cafe = sampleLabel(id: 4, title: 'Café');

      expect(labelTitleToCreate([cafe], 'cafe'), 'cafe');
      expect(labelTitleToCreate([cafe], 'CAFÉ'), isNull);
    });

    test('new labels get a colour of the Okabe–Ito palette, in its order '
        'and without its black', () {
      expect(randomLabelColor(ZeroRandom()), 'e69f00');
      expect(okabeItoColors, [
        'e69f00',
        '56b4e9',
        '009e73',
        'f0e442',
        '0072b2',
        'd55e00',
        'cc79a7',
      ]);
      expect(
        okabeItoColors.every((hex) => RegExp(r'^[0-9a-f]{6}$').hasMatch(hex)),
        isTrue,
      );
      for (final leftOut in ['000000', '7f23ff', '373f47']) {
        expect(okabeItoColors, isNot(contains(leftOut)));
      }
    });
  });

  group('people', () {
    const alice = User(id: 1, username: 'alice', name: 'Alice Example');
    const bob = User(id: 2, username: 'bob');
    const carol = User(id: 3, username: 'cw', name: 'Carol Writer');

    test('filter by username or name', () {
      expect(filterUsers([alice, bob, carol], 'EXAMPLE'), [alice]);
      expect(filterUsers([alice, bob, carol], 'b'), [bob]);
      expect(filterUsers([alice, bob, carol], 'writer'), [carol]);
      expect(filterUsers([alice, bob, carol], ' '), [alice, bob, carol]);
    });

    test('filter ignoring accents, in the query too', () {
      const zoe = User(id: 4, username: 'zoe', name: 'Zoë Müller');
      const jose = User(id: 5, username: 'josé');

      expect(filterUsers([alice, zoe, jose], 'muller'), [zoe]);
      expect(filterUsers([alice, zoe, jose], 'ZOË'), [zoe]);
      expect(filterUsers([alice, zoe, jose], 'jose'), [jose]);
    });

    test('assignees come first, then the results without them', () {
      expect(
        peoplePickerRows(
          assigned: [carol],
          selected: [carol],
          found: [alice, bob, carol],
        ),
        [carol, alice, bob],
      );
    });

    test('an assignee unticked stays listed; someone ticked stays listed '
        'once the query hides them', () {
      expect(
        peoplePickerRows(assigned: [carol], selected: const [], found: [bob]),
        [carol, bob],
      );
      expect(
        peoplePickerRows(assigned: const [], selected: [alice], found: [bob]),
        [alice, bob],
      );
      expect(
        peoplePickerRows(
          assigned: const [],
          selected: [alice],
          found: [bob, alice],
        ),
        [bob, alice],
      );
    });
  });
}
