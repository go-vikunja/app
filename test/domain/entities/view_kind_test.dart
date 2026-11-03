import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/domain/entities/view_kind.dart';

import '../../helpers/builders.dart';

void main() {
  group('ViewKind.fromString', () {
    test('maps each known api value onto its kind', () {
      expect(ViewKind.fromString('list'), ViewKind.list);
      expect(ViewKind.fromString('gantt'), ViewKind.gantt);
      expect(ViewKind.fromString('table'), ViewKind.table);
      expect(ViewKind.fromString('kanban'), ViewKind.kanban);
    });

    test('throws on an unknown value', () {
      expect(() => ViewKind.fromString('calendar'), throwsA(isA<Error>()));
      expect(() => ViewKind.fromString(''), throwsA(isA<Error>()));
    });
  });

  group('ProjectView.icon', () {
    test('gives each view kind its own icon', () {
      IconData iconFor(ViewKind kind) =>
          buildView(kind: kind).icon.icon as IconData;

      expect(iconFor(ViewKind.list), Icons.view_list);
      expect(iconFor(ViewKind.kanban), Icons.view_kanban);
      expect(iconFor(ViewKind.gantt), Icons.view_timeline);
      expect(iconFor(ViewKind.table), Icons.table_chart);
    });
  });
}
