import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/src/dto/project_codec.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';

// Shaped like Vikunja 2.8.0's lists: the user follows Garden (5), so its
// child Beds (6) names Garden; Shed (2) is not followed.
Map<String, Object?> _project(int id, {int parent = 0, Object? subscription}) =>
    {
      'id': id,
      'title': 'Project $id',
      'description': '',
      'identifier': '',
      'hex_color': '',
      'parent_project_id': parent,
      'owner': {
        'id': 1,
        'name': '',
        'username': 'owner',
        'created': '2026-11-09T14:05:52Z',
        'updated': '2026-11-09T14:05:52Z',
      },
      'is_archived': false,
      'background_information': null,
      'background_blur_hash': '',
      'is_favorite': false,
      'subscription': ?subscription,
      'position': id * 65536,
      'views': null,
      'max_permission': 2,
      'created': '2026-11-09T14:05:53Z',
      'updated': '2026-11-09T14:05:53Z',
    };

Map<String, Object?> _followed(int holder, {String entity = 'project'}) => {
  'id': 6,
  'entity': entity,
  'entity_id': holder,
  'created': '2026-11-09T14:05:53Z',
};

const _garden = Subscription(entity: SubscriptionEntity.project, entityId: 5);

void main() {
  group('the subscription of a project', () {
    test('a followed project names itself', () {
      final project = parseProject(_project(5, subscription: _followed(5)));

      expect(project.subscription, _garden);
    });

    test('a child of a followed project names the parent', () {
      final project = parseProject(
        _project(6, parent: 5, subscription: _followed(5)),
      );

      expect(project.subscription, _garden);
      expect(project.parentProjectId, 5);
    });

    test('without the key or with null it is not followed', () {
      expect(parseProject(_project(2)).subscription, isNull);
      expect(
        parseProject({..._project(2), 'subscription': null}).subscription,
        isNull,
      );
    });

    for (final (name, value) in [
      ('a task subscription', _followed(5, entity: 'task')),
      ('a string', 'project:5'),
      ('a map without entity_id', {'id': 6, 'entity': 'project'}),
      ('an unknown entity', _followed(5, entity: 'namespace')),
      (
        'an entity_id that is no number',
        {'id': 6, 'entity': 'project', 'entity_id': '5'},
      ),
    ]) {
      test('$name is unknown, and the rest of the project still parses', () {
        final project = parseProject(_project(5, subscription: value));

        expect(project.subscription, isNull);
        expect(project.id, 5);
        expect(project.title, 'Project 5');
        expect(project.owner, const User(id: 1, username: 'owner'));
        expect(project.maxPermission, Permission.admin);
        expect(project.updated, DateTime.utc(2026, 11, 9, 14, 5, 53));
      });
    }

    test('a v2 list page carries each project its own state', () async {
      const v2 = '$testServerRoot/api/v2';
      final dio = fakeDio({
        '$v2/projects?page=1&expand=permissions': json({
          'items': [
            _project(2),
            _project(5, subscription: _followed(5)),
            _project(6, parent: 5, subscription: _followed(5)),
            _project(7, parent: 6, subscription: 'broken'),
          ],
          'total': 4,
          'page': 1,
          'per_page': 50,
          'total_pages': 1,
        }),
      });

      final page = await createReadClient(
        dio: dio,
        connection: testConnection(version: const ServerVersion(2, 8, 0)),
      ).projects.list();

      expect(
        {for (final project in page.items) project.id: project.subscription},
        {2: null, 5: _garden, 6: _garden, 7: null},
      );
    });
  });
}
