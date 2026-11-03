import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/data/models/project_dto.dart';
import 'package:vikunja_app/domain/entities/view_kind.dart';

import '../../helpers/builders.dart';
import '../../helpers/json_fixtures.dart';

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

  group('ProjectDto colour handling', () {
    Map<String, dynamic> projectJson({String hexColor = ''}) => {
      'id': 1,
      'title': 'Inbox',
      'description': '',
      'hex_color': hexColor,
      'owner': userJson(),
      'is_archived': false,
      'is_favorite': false,
      'parent_project_id': 0,
      'position': 1,
      'views': <Object>[],
      'created': isoDate,
      'updated': isoDate,
    };

    test('turns a hex_color into an opaque Color', () {
      expect(
        ProjectDto.fromJson(projectJson(hexColor: '4287f5')).color,
        const Color(0xFF4287F5),
      );
    });

    test('treats an empty hex_color as no colour', () {
      expect(ProjectDto.fromJson(projectJson()).color, isNull);
    });

    test('writes hex_color back without the alpha channel', () {
      final json = ProjectDto.fromJson(
        projectJson(hexColor: '4287f5'),
      ).toJSON();

      expect(json['hex_color'], '4287f5');
    });

    test('writes a null hex_color when the project has none', () {
      expect(ProjectDto.fromJson(projectJson()).toJSON()['hex_color'], isNull);
    });

    test('widens an integer position to a double', () {
      expect(ProjectDto.fromJson(projectJson()).position, 1.0);
    });
  });

  group('ProjectDto.toJSON extras', () {
    test('writes the remaining api field names and utc timestamps', () {
      final json = ProjectDto.fromJson(
        jsonDecode('''
        {
          "id": 4, "title": "Roadmap", "description": "d", "hex_color": "",
          "owner": null, "is_archived": true, "is_favorite": false,
          "parent_project_id": 2, "position": 3, "views": [],
          "created": "$isoDate", "updated": "$isoDate"
        }
      '''),
      ).toJSON();

      expect(json['parent_project_id'], 2);
      expect(json['is_archived'], isTrue);
      expect(json['position'], 3.0);
      expect(json['owner'], isNull);
      expect(
        json['created'],
        DateTime.parse(isoDate).toUtc().toIso8601String(),
      );
    });
  });

  group('ProjectDto domain conversion', () {
    test('toDomain carries scalars, owner and views', () {
      final project = ProjectDto.fromJson({
        'id': 3,
        'title': 'Roadmap',
        'description': 'Long term',
        'hex_color': '00ff00',
        'owner': userJson(username: 'demo'),
        'is_archived': true,
        'is_favorite': true,
        'parent_project_id': 1,
        'position': 2,
        'views': [projectViewJson(id: 11, projectId: 3, viewKind: 'kanban')],
        'created': isoDate,
        'updated': isoDate,
      }).toDomain();

      expect(project.id, 3);
      expect(project.title, 'Roadmap');
      expect(project.description, 'Long term');
      expect(project.color, const Color(0xFF00FF00));
      expect(project.owner!.username, 'demo');
      expect(project.isArchived, isTrue);
      expect(project.isFavourite, isTrue);
      expect(project.parentProjectId, 1);
      expect(project.position, 2.0);
      expect(project.views.single.viewKind, ViewKind.kanban);
    });

    test('fromDomain round-trips a project with an owner and views', () {
      final back = ProjectDto.fromDomain(
        buildProject(
          id: 6,
          title: 'Team',
          owner: buildUser(username: 'lead'),
          color: const Color(0xFF112233),
          views: [buildView(id: 12, projectId: 6)],
        ),
      ).toDomain();

      expect(back.id, 6);
      expect(back.title, 'Team');
      expect(back.owner!.username, 'lead');
      expect(back.color, const Color(0xFF112233));
      expect(back.views.single.id, 12);
    });

    test('fromDomain keeps a null owner null', () {
      expect(ProjectDto.fromDomain(buildProject(owner: null)).owner, isNull);
    });

    test('a directly constructed dto applies its defaults', () {
      final dto = ProjectDto(title: 'Plain');

      expect(dto.id, 0);
      expect(dto.parentProjectId, 0);
      expect(dto.description, '');
      expect(dto.isArchived, isFalse);
      expect(dto.isFavourite, isFalse);
      expect(dto.views, isEmpty);
      expect(dto.created, isNotNull);
    });
  });
}
