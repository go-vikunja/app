import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/data/models/bucket_configuration_dto.dart';
import 'package:vikunja_app/data/models/bucket_dto.dart';
import 'package:vikunja_app/data/models/filter_dto.dart';

import '../../helpers/builders.dart';
import '../../helpers/json_fixtures.dart';

void main() {
  group('BucketDto.fromJSON', () {
    test('parses the scalar fields', () {
      final dto = BucketDto.fromJSON(
        bucketJson(id: 50, title: 'Doing', limit: 5),
      );

      expect(dto.id, 50);
      expect(dto.title, 'Doing');
      expect(dto.limit, 5);
      expect(dto.projectViewId, 20);
      expect(dto.created, DateTime.parse(isoDate));
      expect(dto.updated, DateTime.parse(isoDate2));
      expect(dto.createdBy.username, 'testuser');
    });

    test('widens an integer position to a double', () {
      expect(BucketDto.fromJSON(bucketJson(position: 3)).position, 3.0);
    });

    test('keeps a double position as-is', () {
      expect(BucketDto.fromJSON(bucketJson(position: 2.5)).position, 2.5);
    });

    test('accepts a null position', () {
      expect(BucketDto.fromJSON(bucketJson(position: null)).position, isNull);
    });

    test('maps a null task list to an empty list', () {
      expect(BucketDto.fromJSON(bucketJson()).tasks, isEmpty);
    });

    test('parses nested tasks', () {
      final dto = BucketDto.fromJSON(
        bucketJson(tasks: [taskJson(id: 1), taskJson(id: 2)]),
      );

      expect(dto.tasks.map((t) => t.id), [1, 2]);
    });
  });

  group('BucketDto.toJSON', () {
    test('uses the api field names and utc timestamps', () {
      final json = BucketDto.fromJSON(bucketJson()).toJSON();

      expect(json['project_view_id'], 20);
      expect(json['created_by'], isA<Map<String, dynamic>>());
      expect(
        json['created'],
        DateTime.parse(isoDate).toUtc().toIso8601String(),
      );
    });

    test('serialises nested tasks', () {
      final json = BucketDto.fromJSON(
        bucketJson(tasks: [taskJson(id: 1)]),
      ).toJSON();

      expect(json['tasks'], hasLength(1));
      expect((json['tasks'] as List).first['id'], 1);
    });
  });

  group('BucketDto domain conversion', () {
    test('toDomain carries scalars and nested tasks', () {
      final bucket = BucketDto.fromJSON(
        bucketJson(id: 7, title: 'Done', limit: 2, tasks: [taskJson(id: 3)]),
      ).toDomain();

      expect(bucket.id, 7);
      expect(bucket.title, 'Done');
      expect(bucket.limit, 2);
      expect(bucket.tasks.single.id, 3);
      expect(bucket.createdBy.username, 'testuser');
    });

    test('fromDomain round-trips a bucket', () {
      final bucket = buildBucket(
        id: 9,
        title: 'Review',
        limit: 4,
        position: 12.0,
        tasks: [buildTask(id: 11)],
      );

      final back = BucketDto.fromDomain(bucket).toDomain();

      expect(back.id, 9);
      expect(back.title, 'Review');
      expect(back.limit, 4);
      expect(back.position, 12.0);
      expect(back.tasks.single.id, 11);
    });

    test('a bucket built without timestamps still gets them', () {
      final bucket = BucketDto(
        projectViewId: 1,
        title: 'New',
        limit: 0,
        createdBy: BucketDto.fromJSON(bucketJson()).createdBy,
      );

      expect(bucket.created, isNotNull);
      expect(bucket.tasks, isEmpty);
    });
  });

  group('FilterDto', () {
    test('fromJson parses the sort and order lists', () {
      final dto = FilterDto.fromJson(filterJson());

      expect(dto.s, 'search term');
      expect(dto.sortBy, ['due_date', 'id']);
      expect(dto.orderBy, ['asc', 'desc']);
      expect(dto.filter, 'done = false');
      expect(dto.filterIncludesNulls, isFalse);
    });

    test('fromJson maps null sort and order lists to empty lists', () {
      final dto = FilterDto.fromJson({
        ...filterJson(),
        'sort_by': null,
        'order_by': null,
      });

      expect(dto.sortBy, isEmpty);
      expect(dto.orderBy, isEmpty);
    });

    test('toJSON uses the camelCase keys the app writes', () {
      final json = FilterDto.fromJson(filterJson()).toJSON();

      expect(json['s'], 'search term');
      expect(json['sortBy'], ['due_date', 'id']);
      expect(json['orderBy'], ['asc', 'desc']);
      expect(json['filterIncludesNulls'], isFalse);
    });

    test('round-trips through the domain', () {
      final back = FilterDto.fromDomain(
        FilterDto.fromJson(filterJson()).toDomain(),
      ).toDomain();

      expect(back.s, 'search term');
      expect(back.filter, 'done = false');
      expect(back.sortBy, ['due_date', 'id']);
    });
  });

  group('BucketConfigurationDto', () {
    test('fromJson parses the nested filter', () {
      final dto = BucketConfigurationDto.fromJson(bucketConfigurationJson());

      expect(dto.title, 'Backlog');
      expect(dto.filter!.filter, 'done = false');
    });

    test('fromJson tolerates a missing filter', () {
      final dto = BucketConfigurationDto.fromJson({
        'title': 'Backlog',
        'filter': null,
      });

      expect(dto.filter, isNull);
    });

    test('fromJson tolerates a filter that is not an object', () {
      final dto = BucketConfigurationDto.fromJson({
        'title': 'Backlog',
        'filter': 'null',
      });

      expect(dto.filter, isNull);
    });

    test('toJSON nests the serialised filter', () {
      final json = BucketConfigurationDto.fromJson(
        bucketConfigurationJson(),
      ).toJSON();

      expect(json['title'], 'Backlog');
      expect(json['filter'], isA<Map<String, dynamic>>());
    });

    test('round-trips through the domain with and without a filter', () {
      final withFilter = BucketConfigurationDto.fromJson(
        bucketConfigurationJson(),
      ).toDomain();
      final without = BucketConfigurationDto.fromJson({
        'title': 'Plain',
        'filter': null,
      }).toDomain();

      expect(BucketConfigurationDto.fromDomain(withFilter).filter, isNotNull);
      expect(BucketConfigurationDto.fromDomain(without).filter, isNull);
      expect(BucketConfigurationDto.fromDomain(without).title, 'Plain');
    });
  });
}
