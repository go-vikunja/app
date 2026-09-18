import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/data/models/project_view_dto.dart';
import 'package:vikunja_app/domain/entities/view_kind.dart';

import '../../helpers/builders.dart';
import '../../helpers/json_fixtures.dart';

void main() {
  group('ProjectViewDto.fromJson', () {
    test('parses the scalar fields', () {
      final dto = ProjectViewDto.fromJson(
        projectViewJson(id: 10, projectId: 1),
      );

      expect(dto.id, 10);
      expect(dto.projectId, 1);
      expect(dto.title, 'List');
      expect(dto.viewKind, 'list');
      expect(dto.bucketConfigurationMode, 'manual');
      expect(dto.defaultBucketId, 0);
      expect(dto.doneBucketId, 0);
      expect(dto.position, 0.0);
      expect(dto.created, DateTime.parse(isoDate));
      expect(dto.updated, DateTime.parse(isoDate2));
    });

    test('parses a nested filter when the api sends an object', () {
      final dto = ProjectViewDto.fromJson(
        projectViewJson(filter: filterJson()),
      );

      expect(dto.filter!.filter, 'done = false');
    });

    test('ignores a filter that is not an object', () {
      expect(
        ProjectViewDto.fromJson(projectViewJson(filter: 'null')).filter,
        isNull,
      );
      expect(
        ProjectViewDto.fromJson(projectViewJson(filter: null)).filter,
        isNull,
      );
    });

    test('parses a bucket configuration list', () {
      final dto = ProjectViewDto.fromJson(
        projectViewJson(
          viewKind: 'kanban',
          bucketConfiguration: [bucketConfigurationJson(title: 'Todo')],
        ),
      );

      expect(dto.bucketConfiguration!.single.title, 'Todo');
    });

    test('leaves the bucket configuration null when absent', () {
      expect(
        ProjectViewDto.fromJson(projectViewJson()).bucketConfiguration,
        isNull,
      );
    });
  });

  group('ProjectViewDto.toJSON', () {
    test('writes the api field names', () {
      final json = ProjectViewDto.fromJson(projectViewJson()).toJSON();

      expect(json['default_bucket_id'], 0);
      expect(json['done_bucket_id'], 0);
      expect(json['project_id'], 1);
      expect(json['view_kind'], 'list');
      expect(json['bucket_configuration_mode'], 'manual');
    });

    test('writes the literal string "null" when there is no filter', () {
      final json = ProjectViewDto.fromJson(projectViewJson()).toJSON();

      expect(json['filter'], 'null');
      expect(json['bucket_configuration'], 'null');
    });

    test('writes nested structures when they exist', () {
      final json = ProjectViewDto.fromJson(
        projectViewJson(
          filter: filterJson(),
          bucketConfiguration: [bucketConfigurationJson()],
        ),
      ).toJSON();

      expect(json['filter'], isA<Map<String, dynamic>>());
      expect(json['bucket_configuration'], hasLength(1));
    });
  });

  group('ProjectViewDto domain conversion', () {
    test('toDomain resolves the view kind enum', () {
      for (final kind in ['list', 'gantt', 'table', 'kanban']) {
        final view = ProjectViewDto.fromJson(
          projectViewJson(viewKind: kind),
        ).toDomain();

        expect(view.viewKind, ViewKind.fromString(kind));
      }
    });

    test('fromDomain lowercases the view kind back to the api value', () {
      for (final kind in ViewKind.values) {
        final dto = ProjectViewDto.fromDomain(buildView(kind: kind));

        expect(dto.viewKind, kind.name);
      }
    });

    test('round-trips a view with a filter and bucket configuration', () {
      final source = ProjectViewDto.fromJson(
        projectViewJson(
          viewKind: 'kanban',
          filter: filterJson(),
          bucketConfiguration: [bucketConfigurationJson(title: 'Todo')],
        ),
      ).toDomain();

      final back = ProjectViewDto.fromDomain(source).toDomain();

      expect(back.viewKind, ViewKind.kanban);
      expect(back.filter!.filter, 'done = false');
      expect(back.bucketConfiguration!.single.title, 'Todo');
    });

    test('round-trips a view without optional structures', () {
      final back = ProjectViewDto.fromDomain(buildView()).toDomain();

      expect(back.filter, isNull);
      expect(back.bucketConfiguration, isNull);
      expect(back.viewKind, ViewKind.list);
    });
  });
}
