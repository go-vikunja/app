import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/data/models/bucket_dto.dart';
import 'package:vikunja_app/data/models/label_dto.dart';
import 'package:vikunja_app/data/models/task_attachment_dto.dart';

// The API returns "created_by": null when the user who created a bucket, label
// or attachment no longer exists (e.g. a deleted bot user). One such bucket used
// to make the whole kanban view fail to parse, so no columns were shown.
void main() {
  const user = '''
    {
      "id": 1,
      "username": "testuser",
      "name": "Test User",
      "created": "2024-01-15T10:30:00Z",
      "updated": "2024-01-16T14:20:00Z"
    }
  ''';

  String bucket(String createdBy) =>
      '''
    {
      "id": 125,
      "project_view_id": 96,
      "title": "To-Do",
      "position": 100,
      "limit": 0,
      "created": "2024-02-01T09:00:00Z",
      "updated": "2024-02-01T09:05:00Z",
      "created_by": $createdBy,
      "tasks": []
    }
  ''';

  String label(String createdBy) =>
      '''
    {
      "id": 7,
      "title": "urgent",
      "description": "",
      "hex_color": "e53935",
      "created": "2024-02-01T09:00:00Z",
      "updated": "2024-02-01T09:05:00Z",
      "created_by": $createdBy
    }
  ''';

  group('BucketDto', () {
    test('parses a bucket whose creator was deleted (created_by: null)', () {
      final dto = BucketDto.fromJSON(jsonDecode(bucket('null')));

      expect(dto.id, 125);
      expect(dto.title, 'To-Do');
      expect(dto.createdBy, isNull);
      expect(dto.toDomain().createdBy, isNull);
      expect(dto.toJSON()['created_by'], isNull);
    });

    test('still parses the creator when present', () {
      final dto = BucketDto.fromJSON(jsonDecode(bucket(user)));

      expect(dto.createdBy?.username, 'testuser');
      expect(dto.toDomain().createdBy?.id, 1);
    });

    test('round-trips through the domain model without a creator', () {
      final domain = BucketDto.fromJSON(jsonDecode(bucket('null'))).toDomain();
      final roundTrip = BucketDto.fromDomain(domain);

      expect(roundTrip.id, 125);
      expect(roundTrip.createdBy, isNull);
    });
  });

  group('LabelDto', () {
    test('parses a label whose creator was deleted (created_by: null)', () {
      final dto = LabelDto.fromJson(jsonDecode(label('null')));

      expect(dto.title, 'urgent');
      expect(dto.createdBy, isNull);
      expect(dto.toDomain().createdBy, isNull);
      expect(LabelDto.fromDomain(dto.toDomain()).createdBy, isNull);
    });

    test('still parses the creator when present', () {
      final dto = LabelDto.fromJson(jsonDecode(label(user)));

      expect(dto.createdBy?.username, 'testuser');
    });
  });

  group('TaskAttachmentDto', () {
    test(
      'parses an attachment whose creator was deleted (created_by: null)',
      () {
        final json = '''
        {
          "id": 3,
          "task_id": 42,
          "created": "2024-02-01T09:00:00Z",
          "created_by": null,
          "file": {
            "id": 9,
            "created": "2024-02-01T09:00:00Z",
            "mime": "image/jpeg",
            "name": "photo.jpg",
            "size": 1234
          }
        }
      ''';

        final dto = TaskAttachmentDto.fromJSON(jsonDecode(json));

        expect(dto.taskId, 42);
        expect(dto.createdBy, isNull);
        expect(dto.toDomain().createdBy, isNull);
        expect(dto.toJSON()['created_by'], isNull);
      },
    );
  });
}
