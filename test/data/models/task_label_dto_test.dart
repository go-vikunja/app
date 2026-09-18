import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/data/models/label_dto.dart';
import 'package:vikunja_app/data/models/task_label_bulk_dto.dart';
import 'package:vikunja_app/data/models/task_label_dto.dart';
import 'package:vikunja_app/data/models/user_dto.dart';
import 'package:vikunja_app/domain/entities/task_label.dart';

import '../../helpers/builders.dart';
import '../../helpers/json_fixtures.dart';

void main() {
  group('LabelTaskDto', () {
    test('fromJson builds a stub label from just the label_id', () {
      final dto = LabelTaskDto.fromJson({
        'label_id': 42,
      }, UserDto.fromJson(userJson()));

      expect(dto.label.id, 42);
      expect(dto.label.title, '');
      expect(dto.task, isNull);
    });

    test('toJSON sends only the label id', () {
      final dto = LabelTaskDto.fromDomain(
        LabelTask(label: buildLabel(id: 9), task: buildTask()),
      );

      expect(dto.toJSON(), {'label_id': 9});
    });

    test('toDomain carries the label and the optional task', () {
      final domain = LabelTaskDto.fromDomain(
        LabelTask(label: buildLabel(id: 9), task: buildTask(id: 3)),
      ).toDomain();

      expect(domain.label.id, 9);
      expect(domain.task!.id, 3);
    });

    test('toDomain keeps a null task null', () {
      final domain = LabelTaskDto.fromDomain(
        LabelTask(label: buildLabel(id: 9), task: null),
      ).toDomain();

      expect(domain.task, isNull);
    });
  });

  group('LabelTaskBulkDto', () {
    test('toJSON wraps the serialised labels under a labels key', () {
      final dto = LabelTaskBulkDto(
        labels: [
          LabelDto.fromJson(labelJson(id: 1, title: 'A')),
          LabelDto.fromJson(labelJson(id: 2, title: 'B')),
        ],
      );

      final json = dto.toJSON();

      expect(json.keys, ['labels']);
      expect(json['labels']!.map((l) => l['id']), [1, 2]);
    });

    test('toJSON sends an empty list when there are no labels', () {
      expect(LabelTaskBulkDto(labels: []).toJSON(), {'labels': <Object>[]});
    });
  });
}
