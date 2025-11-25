import 'dart:convert';

import 'package:test/test.dart';
import 'package:vikunja_app/data/models/task_comment_dto.dart';

void main() {
  group('TaskCommentDto.fromJson', () {
    test('parses comment with all fields', () {
      final json = '''
        {
          "id": 42,
          "comment": "This is a test comment",
          "author": {
            "id": 1,
            "username": "testuser",
            "name": "Test User",
            "created": "2024-01-15T10:30:00Z",
            "updated": "2024-01-16T14:20:00Z"
          },
          "created": "2024-02-01T09:00:00Z",
          "updated": "2024-02-01T09:05:00Z"
        }
      ''';

      final comment = TaskCommentDto.fromJson(jsonDecode(json));

      expect(comment.id, 42);
      expect(comment.comment, 'This is a test comment');
      expect(comment.author.id, 1);
      expect(comment.author.username, 'testuser');
      expect(comment.created, DateTime.utc(2024, 2, 1, 9, 0, 0));
      expect(comment.updated, DateTime.utc(2024, 2, 1, 9, 5, 0));
    });

    test('parses comment with missing optional id', () {
      final json = '''
        {
          "comment": "New comment without id",
          "author": {
            "id": 1,
            "username": "testuser",
            "name": "Test User",
            "created": "2024-01-15T10:30:00Z",
            "updated": "2024-01-16T14:20:00Z"
          },
          "created": "2024-02-01T09:00:00Z",
          "updated": "2024-02-01T09:05:00Z"
        }
      ''';

      final comment = TaskCommentDto.fromJson(jsonDecode(json));

      expect(comment.id, 0);
      expect(comment.comment, 'New comment without id');
    });

    test('parses comment with empty comment text', () {
      final json = '''
        {
          "id": 1,
          "author": {
            "id": 1,
            "username": "testuser",
            "name": "Test User",
            "created": "2024-01-15T10:30:00Z",
            "updated": "2024-01-16T14:20:00Z"
          },
          "created": "2024-02-01T09:00:00Z",
          "updated": "2024-02-01T09:05:00Z"
        }
      ''';

      final comment = TaskCommentDto.fromJson(jsonDecode(json));

      expect(comment.comment, '');
    });
  });

  group('TaskCommentDto.toJSON', () {
    test('serializes comment to JSON', () {
      final json = '''
        {
          "id": 42,
          "comment": "Test comment",
          "author": {
            "id": 1,
            "username": "testuser",
            "name": "Test User",
            "created": "2024-01-15T10:30:00Z",
            "updated": "2024-01-16T14:20:00Z"
          },
          "created": "2024-02-01T09:00:00Z",
          "updated": "2024-02-01T09:05:00Z"
        }
      ''';

      final comment = TaskCommentDto.fromJson(jsonDecode(json));
      final output = comment.toJSON();

      expect(output['id'], 42);
      expect(output['comment'], 'Test comment');
      expect(output['author']['username'], 'testuser');
    });
  });

  group('TaskCommentDto.toDomain', () {
    test('converts to domain TaskComment', () {
      final json = '''
        {
          "id": 42,
          "comment": "Domain test",
          "author": {
            "id": 1,
            "username": "testuser",
            "name": "Test User",
            "created": "2024-01-15T10:30:00Z",
            "updated": "2024-01-16T14:20:00Z"
          },
          "created": "2024-02-01T09:00:00Z",
          "updated": "2024-02-01T09:05:00Z"
        }
      ''';

      final dto = TaskCommentDto.fromJson(jsonDecode(json));
      final comment = dto.toDomain();

      expect(comment.id, 42);
      expect(comment.comment, 'Domain test');
      expect(comment.author.id, 1);
      expect(comment.author.username, 'testuser');
      expect(comment.created, DateTime.utc(2024, 2, 1, 9, 0, 0));
    });
  });

  group('TaskCommentDto.fromDomain', () {
    test('converts from domain TaskComment', () {
      final json = '''
        {
          "id": 42,
          "comment": "Round trip test",
          "author": {
            "id": 1,
            "username": "testuser",
            "name": "Test User",
            "created": "2024-01-15T10:30:00Z",
            "updated": "2024-01-16T14:20:00Z"
          },
          "created": "2024-02-01T09:00:00Z",
          "updated": "2024-02-01T09:05:00Z"
        }
      ''';

      final original = TaskCommentDto.fromJson(jsonDecode(json));
      final domain = original.toDomain();
      final roundTrip = TaskCommentDto.fromDomain(domain);

      expect(roundTrip.id, original.id);
      expect(roundTrip.comment, original.comment);
      expect(roundTrip.author.id, original.author.id);
      expect(roundTrip.created, original.created);
    });
  });
}
