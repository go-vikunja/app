import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
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

    test('offer to create the trimmed query unless a title matches '
        'exactly', () {
      expect(labelTitleToCreate(labels, ' Gard '), 'Gard');
      expect(labelTitleToCreate(labels, 'garden'), isNull);
      expect(labelTitleToCreate(labels, '   '), isNull);
      expect(labelTitleToCreate(const [], 'New'), 'New');
    });

    test('new labels get a colour of the web palette', () {
      expect(randomLabelColor(ZeroRandom()), 'ffbe0b');
      expect(newLabelColors, hasLength(13));
      expect(
        newLabelColors.every((hex) => RegExp(r'^[0-9a-f]{6}$').hasMatch(hex)),
        isTrue,
      );
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
