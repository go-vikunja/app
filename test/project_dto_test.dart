import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/data/models/project_dto.dart';

void main() {
  group('ProjectDto.fromJson', () {
    test('parses a regular project', () {
      final json = '''
        {
          "id": 1,
          "title": "Inbox",
          "description": "",
          "identifier": "",
          "hex_color": "",
          "owner": {
            "id": 1,
            "username": "demo",
            "name": "Demo",
            "created": "2024-01-15T10:30:00Z",
            "updated": "2024-01-16T14:20:00Z"
          },
          "is_archived": false,
          "is_favorite": true,
          "parent_project_id": 0,
          "position": 1,
          "views": [],
          "created": "2024-02-01T09:00:00Z",
          "updated": "2024-02-01T09:05:00Z"
        }
      ''';

      final project = ProjectDto.fromJson(jsonDecode(json));

      expect(project.id, 1);
      expect(project.title, 'Inbox');
      expect(project.parentProjectId, 0);
      expect(project.isArchived, false);
      expect(project.isFavourite, true);
      expect(project.owner?.username, 'demo');
    });

    // Vikunja 2.4.0 omits parent_project_id for pseudo projects, which used to
    // crash the whole project list. See go-vikunja/app#295.
    test('parses a pseudo project without parent_project_id', () {
      final json = '''
        {
          "id": -1,
          "title": "Favorites",
          "description": "This project has all tasks marked as favorites.",
          "identifier": "",
          "hex_color": "",
          "owner": null,
          "is_archived": false,
          "is_favorite": true,
          "position": -1,
          "views": [
            {
              "id": -1,
              "title": "List",
              "project_id": -1,
              "view_kind": "list",
              "filter": {
                "s": "",
                "sort_by": null,
                "order_by": null,
                "filter": "done = false",
                "filter_include_nulls": false
              },
              "position": 100,
              "bucket_configuration_mode": "none",
              "bucket_configuration": null,
              "default_bucket_id": 0,
              "done_bucket_id": 0,
              "created": "0001-01-01T00:00:00Z",
              "updated": "0001-01-01T00:00:00Z"
            }
          ],
          "created": "2026-07-25T04:00:03.1556459Z",
          "updated": "2026-07-25T04:00:03.155648465Z"
        }
      ''';

      final project = ProjectDto.fromJson(jsonDecode(json));

      expect(project.id, -1);
      expect(project.title, 'Favorites');
      expect(project.parentProjectId, 0);
      expect(project.isFavourite, true);
      expect(project.owner, isNull);
      expect(project.views.length, 1);
    });
  });

  group('ProjectDto.toJSON', () {
    test('serializes is_favorite with the field name the api uses', () {
      final project = ProjectDto(title: 'Test', isFavourite: true);

      expect(project.toJSON()['is_favorite'], true);
    });
  });
}
