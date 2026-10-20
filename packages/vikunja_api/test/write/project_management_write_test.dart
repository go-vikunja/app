import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';

// The answers were captured by tool/capture_project_fixtures.dart: Studio
// 1358 (colour e8b04a) at the top level, its child Sketches 1359, renamed
// Drafts with identifier DRF, the copies 1360 (v1) and 1361 (v2), the views
// Open 7450 (a list) and Board 7451 (a kanban) of Studio, and the user's
// default project 1357. Each capture keeps the body it sent as `sent`.
const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';
const _studio = 1358;
const _sketches = 1359;
const _v1Copy = 1360;
const _v2Copy = 1361;
const _inbox = 1357;
const _open = 7450;
const _board = 7451;

VikunjaWriteClient _client(Dio dio, {required bool hasV2}) => createWriteClient(
  dio: dio,
  connection: testConnection(hasV2: hasV2),
);

List<String> _calls(Dio dio) => [
  for (final request in adapterOf(dio).requests)
    '${request.method} ${request.uri}',
];

FakeRoute _byMethod(Map<String, FakeRoute> routes) =>
    (request) => (routes[request.method] ?? refused)(request);

FakeRoute _write(String name) => capturedFixture('write/${name}_2.7.0');

Object? _sent(String name) => fixtureJson('write/${name}_2.7.0.json')['sent'];

Map<String, Object?> _lastBody(Dio dio) =>
    adapterOf(dio).decodedBodies.last! as Map<String, Object?>;

String _contentType(Dio dio) =>
    adapterOf(dio).requests.last.headers['content-type'] as String;

Matcher _domainError(int status, int code) => isA<DomainError>()
    .having((f) => f.statusCode, 'status', status)
    .having((f) => f.code, 'code', code);

const _drafts = ProjectChanges(
  title: 'Drafts',
  identifier: 'drf',
  hexColor: '00db60',
);

ViewDraft _filtered(String title, String filter, {double? position}) =>
    ViewDraft(
      title: title,
      kind: ProjectViewKind.list,
      filter: ViewFilter(filter: filter),
      position: position,
    );

void main() {
  group('project create', () {
    test('v1 puts only the title and the colour of a top-level project and '
        'returns it with its default views', () async {
      final dio = fakeDio({'$_v1/projects': _write('v1_project_create')});

      final project = await _client(
        dio,
        hasV2: false,
      ).projects.create(const NewProject(title: 'Studio', hexColor: 'e8b04a'));

      expect(_calls(dio), ['PUT $_v1/projects']);
      expect(adapterOf(dio).decodedBodies, [_sent('v1_project_create')]);
      expect(project.id, _studio);
      expect(project.title, 'Studio');
      expect(project.hexColor, 'e8b04a');
      expect(project.parentProjectId, 0);
      expect(project.position, 88997888);
      expect([
        for (final view in project.views) view.kind,
      ], ProjectViewKind.values);
      expect(project.views.first.filter?.filter, 'done = false');
    });

    test('v2 posts the parent and the colour without #', () async {
      final dio = fakeDio({'$_v2/projects': _write('v2_project_create')});

      final project = await _client(dio, hasV2: true).projects.create(
        const NewProject(
          title: 'Sketches',
          parentProjectId: _studio,
          hexColor: '#4a90e2',
        ),
      );

      expect(_calls(dio), ['POST $_v2/projects']);
      expect(adapterOf(dio).decodedBodies, [_sent('v2_project_create')]);
      expect(project.id, _sketches);
      expect(project.parentProjectId, _studio);
      expect(project.hexColor, '4a90e2');
      expect(project.views, hasLength(4));
    });

    test('without a colour only the title is sent', () async {
      final dio = fakeDio({'$_v2/projects': _write('v2_project_create')});

      await _client(
        dio,
        hasV2: true,
      ).projects.create(const NewProject(title: 'Plain'));

      expect(adapterOf(dio).decodedBodies, [
        {'title': 'Plain'},
      ]);
    });

    test('an archived parent is refused with 3008', () async {
      final dio = fakeDio({
        '$_v2/projects': _write('v2_project_create_archived_parent'),
      });

      await expectLater(
        _client(dio, hasV2: true).projects.create(
          const NewProject(title: 'Studies', parentProjectId: _studio),
        ),
        throwsA(_domainError(412, 3008)),
      );
    });
  });

  group('v2 project update', () {
    test('sends a merge-patch with only the set fields and returns the '
        'project as stored', () async {
      final dio = fakeDio({
        '$_v2/projects/$_sketches': _write('v2_project_update'),
      });

      final project = await _client(
        dio,
        hasV2: true,
      ).projects.update(_sketches, _drafts);

      expect(_calls(dio), ['PATCH $_v2/projects/$_sketches']);
      expect(_contentType(dio), 'application/merge-patch+json');
      expect(adapterOf(dio).decodedBodies, [_sent('v2_project_update')]);
      expect(project.title, 'Drafts');
      expect(project.identifier, 'DRF');
      expect(project.hexColor, '00db60');
      expect(project.parentProjectId, _studio);
      expect(project.position, 89063424);
    });

    test('reads the project when nothing changed (304)', () async {
      final dio = fakeDio({
        '$_v2/projects/$_sketches': _byMethod({
          'PATCH': _write('v2_project_update_unchanged'),
          'GET': _write('v2_project_update_read'),
        }),
      });

      final project = await _client(
        dio,
        hasV2: true,
      ).projects.update(_sketches, const ProjectChanges(title: 'Drafts'));

      expect(_calls(dio), [
        'PATCH $_v2/projects/$_sketches',
        'GET $_v2/projects/$_sketches',
      ]);
      expect(adapterOf(dio).decodedBodies.first, {'title': 'Drafts'});
      expect(project.title, 'Drafts');
    });

    test('an empty colour and identifier are sent to clear them', () async {
      final dio = fakeDio({
        '$_v2/projects/$_sketches': _write('v2_project_update'),
      });

      await _client(dio, hasV2: true).projects.update(
        _sketches,
        const ProjectChanges(identifier: '', hexColor: ''),
      );

      expect(adapterOf(dio).decodedBodies, [
        {'identifier': '', 'hex_color': ''},
      ]);
    });

    test('the parent, the favourite and the archive state are sent as '
        'given', () async {
      final dio = fakeDio({
        '$_v2/projects/$_studio': _write('v2_project_archive'),
      });

      final project = await _client(dio, hasV2: true).projects.update(
        _studio,
        const ProjectChanges(
          parentProjectId: 0,
          isFavorite: false,
          isArchived: true,
        ),
      );

      expect(adapterOf(dio).decodedBodies, [
        {'parent_project_id': 0, 'is_favorite': false, 'is_archived': true},
      ]);
      expect(project.isArchived, isTrue);
    });

    test('a position is sent with the other changes', () async {
      final dio = fakeDio({
        '$_v2/projects/$_studio': _write('v2_project_archive'),
      });

      await _client(dio, hasV2: true).projects.update(
        _studio,
        const ProjectChanges(isFavorite: true, position: 0.1),
      );

      expect(adapterOf(dio).decodedBodies, [
        {'is_favorite': true, 'position': 0.1},
      ]);
    });

    test('archiving sends only the flag', () async {
      final dio = fakeDio({
        '$_v2/projects/$_studio': _write('v2_project_archive'),
      });

      await _client(
        dio,
        hasV2: true,
      ).projects.update(_studio, const ProjectChanges(isArchived: true));

      expect(adapterOf(dio).decodedBodies, [_sent('v2_project_archive')]);
    });

    final refusals = <String, ({int projectId, Matcher matcher})>{
      'v2_project_update_identifier_taken': (
        projectId: _studio,
        matcher: _domainError(400, 3007),
      ),
      'v2_project_update_archived': (
        projectId: _studio,
        matcher: _domainError(412, 3008),
      ),
      'v2_project_unarchive_parent_archived': (
        projectId: _sketches,
        matcher: _domainError(412, 3016),
      ),
      'v2_project_archive_default': (
        projectId: _inbox,
        matcher: _domainError(412, 3013),
      ),
    };
    for (final MapEntry(key: name, value: (:projectId, :matcher))
        in refusals.entries) {
      test('$name is refused as captured, without a read', () async {
        final dio = fakeDio({'$_v2/projects/$projectId': _write(name)});

        await expectLater(
          _client(
            dio,
            hasV2: true,
          ).projects.update(projectId, const ProjectChanges(isArchived: true)),
          throwsA(matcher),
        );
        expect(_calls(dio), ['PATCH $_v2/projects/$projectId']);
      });
    }
  });

  group('v1 project update', () {
    test('reads the project and posts it back whole with the change '
        'overlaid', () async {
      final dio = fakeDio({
        '$_v1/projects/$_sketches': _byMethod({
          'GET': _write('v1_project_update_read'),
          'POST': _write('v1_project_update'),
        }),
      });

      final project = await _client(
        dio,
        hasV2: false,
      ).projects.update(_sketches, const ProjectChanges(isFavorite: true));

      expect(_calls(dio), [
        'GET $_v1/projects/$_sketches',
        'POST $_v1/projects/$_sketches',
      ]);
      final sent = _lastBody(dio);
      expect(sent, _sent('v1_project_update'));
      expect(sent, containsPair('identifier', 'DRF'));
      expect(sent, containsPair('hex_color', '00db60'));
      expect(sent, containsPair('position', 89063424));
      expect(sent, containsPair('is_archived', false));
      expect(sent, containsPair('parent_project_id', _studio));
      expect(project.isFavorite, isTrue);
      expect(project.identifier, 'DRF');
    });

    test('overlays every set field, the colour without #', () async {
      final dio = fakeDio({
        '$_v1/projects/$_sketches': _byMethod({
          'GET': _write('v1_project_update_read'),
          'POST': _write('v1_project_update'),
        }),
      });

      await _client(dio, hasV2: false).projects.update(
        _sketches,
        const ProjectChanges(
          title: 'Doodles',
          identifier: '',
          hexColor: '#ABCDEF',
          parentProjectId: 0,
          isArchived: true,
        ),
      );

      final sent = _lastBody(dio);
      expect(sent, {
        ..._sent('v1_project_update')! as Map<String, Object?>,
        'is_favorite': false,
        'title': 'Doodles',
        'identifier': '',
        'hex_color': 'ABCDEF',
        'parent_project_id': 0,
        'is_archived': true,
      });
    });

    test('a project that is gone fails on the read; nothing is '
        'posted', () async {
      final dio = fakeDio({
        '$_v1/projects/$_sketches': _byMethod({
          'GET': json({
            'code': 3001,
            'message': 'This project does not exist.',
          }, status: 404),
        }),
      });

      await expectLater(
        _client(
          dio,
          hasV2: false,
        ).projects.update(_sketches, const ProjectChanges(title: 'x')),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 3001)),
      );
      expect(_calls(dio), ['GET $_v1/projects/$_sketches']);
    });
  });

  for (final hasV2 in [true, false]) {
    final version = hasV2 ? 'v2' : 'v1';
    final base = hasV2 ? _v2 : _v1;

    for (final position in [0.09, -1.0, double.nan, double.infinity]) {
      test('$version project update to position $position is refused before '
          'any request', () async {
        final dio = fakeDio({});

        await expectLater(
          _client(dio, hasV2: hasV2).projects.update(
            _studio,
            ProjectChanges(isFavorite: true, position: position),
          ),
          throwsArgumentError,
        );
        expect(_calls(dio), isEmpty);
      });
    }

    test('$version project update without changes is a read', () async {
      final dio = fakeDio({
        '$base/projects/$_sketches': _write('${version}_project_update_read'),
      });

      final project = await _client(
        dio,
        hasV2: hasV2,
      ).projects.update(_sketches, const ProjectChanges());

      expect(_calls(dio), ['GET $base/projects/$_sketches']);
      expect(project.title, 'Drafts');
    });

    group('$version project delete', () {
      test('sends DELETE', () async {
        final dio = fakeDio({
          '$base/projects/$_v1Copy': _write('${version}_project_delete'),
        });

        await _client(dio, hasV2: hasV2).projects.delete(_v1Copy);

        expect(_calls(dio), ['DELETE $base/projects/$_v1Copy']);
      });

      test('a project that is gone (3001) counts as deleted', () async {
        final dio = fakeDio({
          '$base/projects/$_v2Copy': _write('v2_project_delete_unknown'),
        });

        await _client(dio, hasV2: hasV2).projects.delete(_v2Copy);
      });

      test('a missing route is not a deleted project', () async {
        final dio = fakeDio({
          '$base/projects/$_v2Copy': json({
            'message': 'Not Found',
          }, status: 404),
        });

        await expectLater(
          _client(dio, hasV2: hasV2).projects.delete(_v2Copy),
          throwsA(isA<NotFound>()),
        );
      });

      test('a write share is refused', () async {
        final dio = fakeDio({
          '$base/projects/$_studio': _write('v2_project_delete_not_admin'),
        });

        await expectLater(
          _client(dio, hasV2: hasV2).projects.delete(_studio),
          throwsA(isA<Forbidden>()),
        );
      });
    });

    group('$version project duplicate', () {
      for (final id in [0, -1, -5]) {
        test('pseudo project $id is refused before any request', () async {
          final dio = fakeDio({});

          await expectLater(
            _client(
              dio,
              hasV2: hasV2,
            ).projects.duplicate(id, parentProjectId: 0, copyShares: true),
            throwsArgumentError,
          );
          expect(adapterOf(dio).requests, isEmpty);
        });
      }
    });
  }

  group('project duplicate', () {
    test('v1 puts the parent and the share choice and returns the '
        'copy', () async {
      final dio = fakeDio({
        '$_v1/projects/$_studio/duplicate': _write('v1_project_duplicate'),
      });

      final copy = await _client(
        dio,
        hasV2: false,
      ).projects.duplicate(_studio, parentProjectId: 0, copyShares: false);

      expect(_calls(dio), ['PUT $_v1/projects/$_studio/duplicate']);
      expect(adapterOf(dio).decodedBodies, [_sent('v1_project_duplicate')]);
      expect(copy.id, _v1Copy);
      expect(copy.title, 'Studio - duplicate');
      expect(copy.identifier, '');
      expect(copy.parentProjectId, 0);
      expect(copy.position, 88997888);
      expect(copy.views, hasLength(4));
    });

    test('v2 posts them and returns the copy under the parent', () async {
      final dio = fakeDio({
        '$_v2/projects/$_studio/duplicate': _write('v2_project_duplicate'),
      });

      final copy = await _client(
        dio,
        hasV2: true,
      ).projects.duplicate(_studio, parentProjectId: _studio, copyShares: true);

      expect(_calls(dio), ['POST $_v2/projects/$_studio/duplicate']);
      expect(adapterOf(dio).decodedBodies, [_sent('v2_project_duplicate')]);
      expect(copy.id, _v2Copy);
      expect(copy.parentProjectId, _studio);
      expect(copy.isFavorite, isFalse);
    });

    test('an answer without the copy is unexpected', () async {
      final dio = fakeDio({
        '$_v2/projects/$_studio/duplicate': json({
          'parent_project_id': 0,
        }, status: 201),
      });

      await expectLater(
        _client(
          dio,
          hasV2: true,
        ).projects.duplicate(_studio, parentProjectId: 0, copyShares: false),
        throwsA(isA<UnexpectedResponse>()),
      );
    });
  });

  group('view create', () {
    const views = '/projects/$_studio/views';

    test('v1 puts the title, the kind and the whole filter and returns the '
        'view', () async {
      final dio = fakeDio({'$_v1$views': _write('v1_view_create')});

      final view = await _client(
        dio,
        hasV2: false,
      ).views.create(_studio, _filtered('Open', 'done = false'));

      expect(_calls(dio), ['PUT $_v1$views']);
      expect(adapterOf(dio).decodedBodies, [_sent('v1_view_create')]);
      expect(view.id, _open);
      expect(view.projectId, _studio);
      expect(view.kind, ProjectViewKind.list);
      expect(view.filter, const ViewFilter(filter: 'done = false'));
      expect(view.position, 488243200);
    });

    test('v2 posts a board at a position without a filter or a mode and '
        'returns it manual with its buckets', () async {
      final dio = fakeDio({'$_v2$views': _write('v2_view_create')});

      final view = await _client(dio, hasV2: true).views.create(
        _studio,
        const ViewDraft(
          title: 'Board',
          kind: ProjectViewKind.kanban,
          position: 150,
        ),
      );

      expect(_calls(dio), ['POST $_v2$views']);
      expect(adapterOf(dio).decodedBodies, [_sent('v2_view_create')]);
      expect(_lastBody(dio), isNot(contains('project_id')));
      expect(view.id, _board);
      expect(view.bucketConfigurationMode, BucketConfigurationMode.manual);
      expect(view.defaultBucketId, isNot(0));
      expect(view.doneBucketId, isNot(0));
      expect(view.filter, isNull);
    });

    test('a mode is sent when given', () async {
      final dio = fakeDio({'$_v2$views': _write('v2_view_create')});

      await _client(dio, hasV2: true).views.create(
        _studio,
        const ViewDraft(
          title: 'Board',
          kind: ProjectViewKind.kanban,
          bucketConfigurationMode: BucketConfigurationMode.filter,
        ),
      );

      expect(adapterOf(dio).decodedBodies, [
        {
          'title': 'Board',
          'view_kind': 'kanban',
          'bucket_configuration_mode': 'filter',
        },
      ]);
    });

    final refusals = <String, Matcher>{
      'v2_view_create_filter_syntax': _domainError(400, 4024),
      'v2_view_create_filter_value': _domainError(400, 4019),
      'v2_view_create_filter_field': _domainError(400, 4016),
      'v2_view_create_not_admin': isA<Forbidden>().having(
        (f) => f.code,
        'code',
        isNull,
      ),
    };
    for (final MapEntry(key: name, value: matcher) in refusals.entries) {
      test('$name is refused as captured', () async {
        final dio = fakeDio({'$_v2$views': _write(name)});

        await expectLater(
          _client(dio, hasV2: true).views.create(_studio, _filtered('x', '')),
          throwsA(matcher),
        );
      });
    }

    test('the server message of an invalid filter is kept', () async {
      final dio = fakeDio({
        '$_v2$views': _write('v2_view_create_filter_syntax'),
      });

      await expectLater(
        _client(dio, hasV2: true).views.create(_studio, _filtered('x', '((')),
        throwsA(
          isA<DomainError>().having(
            (f) => f.message,
            'message',
            contains("'(('"),
          ),
        ),
      );
    });
  });

  group('v2 view update', () {
    const open = '/projects/$_studio/views/$_open';

    test('sends a merge-patch with the draft and returns the view as '
        'stored', () async {
      final dio = fakeDio({'$_v2$open': _write('v2_view_update')});

      final view = await _client(dio, hasV2: true).views.update(
        _studio,
        _open,
        _filtered('Urgent', 'priority >= 3', position: 50),
      );

      expect(_calls(dio), ['PATCH $_v2$open']);
      expect(_contentType(dio), 'application/merge-patch+json');
      expect(adapterOf(dio).decodedBodies, [_sent('v2_view_update')]);
      expect(view.title, 'Urgent');
      expect(view.filter?.filter, 'priority >= 3');
      expect(view.position, 50);
    });

    test('reads the view when nothing changed (304)', () async {
      final dio = fakeDio({
        '$_v2$open': _byMethod({
          'PATCH': _write('v2_view_update_unchanged'),
          'GET': _write('v2_view_update_read'),
        }),
      });

      final view = await _client(dio, hasV2: true).views.update(
        _studio,
        _open,
        _filtered('Urgent', 'priority >= 3', position: 50),
      );

      expect(_calls(dio), ['PATCH $_v2$open', 'GET $_v2$open']);
      expect(view.title, 'Urgent');
    });

    test('a draft without a filter clears it', () async {
      final dio = fakeDio({'$_v2$open': _write('v2_view_update_clear_filter')});

      final view = await _client(dio, hasV2: true).views.update(
        _studio,
        _open,
        const ViewDraft(title: 'Urgent', kind: ProjectViewKind.list),
      );

      expect(adapterOf(dio).decodedBodies, [
        _sent('v2_view_update_clear_filter'),
      ]);
      expect(view.filter, isNull);
    });

    test('a view that is gone is NotFound 3014', () async {
      final dio = fakeDio({'$_v2$open': _write('v2_view_delete_unknown')});

      await expectLater(
        _client(
          dio,
          hasV2: true,
        ).views.update(_studio, _open, _filtered('Urgent', '')),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 3014)),
      );
    });
  });

  group('v1 view update', () {
    const board = '/projects/$_studio/views/$_board';

    test('reads the view and posts every field back with the draft '
        'overlaid', () async {
      final dio = fakeDio({
        '$_v1$board': _byMethod({
          'GET': _write('v1_view_update_read'),
          'POST': _write('v1_view_update'),
        }),
      });

      final view = await _client(dio, hasV2: false).views.update(
        _studio,
        _board,
        const ViewDraft(
          title: 'Columns',
          kind: ProjectViewKind.kanban,
          filter: ViewFilter(filter: 'done = false'),
          position: 175,
        ),
      );

      expect(_calls(dio), ['GET $_v1$board', 'POST $_v1$board']);
      final sent = _lastBody(dio);
      expect(sent, _sent('v1_view_update'));
      expect(sent, containsPair('project_id', _studio));
      expect(sent, containsPair('bucket_configuration_mode', 'manual'));
      expect(view.title, 'Columns');
      expect(view.kind, ProjectViewKind.kanban);
      expect(view.position, 175);
      expect(view.defaultBucketId, isNot(0));
      expect(view.doneBucketId, isNot(0));
    });
  });

  group('view move', () {
    const open = '/projects/$_studio/views/$_open';
    const board = '/projects/$_studio/views/$_board';

    test('v2 sends a merge-patch of the position alone', () async {
      final dio = fakeDio({'$_v2$open': _write('v2_view_update')});

      final view = await _client(
        dio,
        hasV2: true,
      ).views.move(_studio, _open, position: 50);

      expect(_calls(dio), ['PATCH $_v2$open']);
      expect(_contentType(dio), 'application/merge-patch+json');
      expect(adapterOf(dio).decodedBodies, [
        {'position': 50},
      ]);
      expect(view.position, 50);
    });

    test('v2 reads the view when the position is unchanged (304)', () async {
      final dio = fakeDio({
        '$_v2$open': _byMethod({
          'PATCH': _write('v2_view_update_unchanged'),
          'GET': _write('v2_view_update_read'),
        }),
      });

      await _client(dio, hasV2: true).views.move(_studio, _open, position: 50);

      expect(_calls(dio), ['PATCH $_v2$open', 'GET $_v2$open']);
    });

    test('v1 posts the view as read with only the position changed', () async {
      final dio = fakeDio({
        '$_v1$board': _byMethod({
          'GET': _write('v1_view_update_read'),
          'POST': _write('v1_view_update'),
        }),
      });

      await _client(
        dio,
        hasV2: false,
      ).views.move(_studio, _board, position: 175);

      expect(_calls(dio), ['GET $_v1$board', 'POST $_v1$board']);
      final read = jsonDecode(
        fixtureJson('write/v1_view_update_read_2.7.0.json')['body']! as String,
      ) as Map<String, Object?>;
      expect(_lastBody(dio), {...read, 'position': 175});
    });
  });

  for (final hasV2 in [true, false]) {
    final version = hasV2 ? 'v2' : 'v1';
    final base = hasV2 ? _v2 : _v1;
    const board = '/projects/$_studio/views/$_board';

    group('$version view delete', () {
      test('sends DELETE', () async {
        final dio = fakeDio({'$base$board': _write('${version}_view_delete')});

        await _client(dio, hasV2: hasV2).views.delete(_studio, _board);

        expect(_calls(dio), ['DELETE $base$board']);
      });

      test('a view that is gone (3014) counts as deleted', () async {
        final dio = fakeDio({'$base$board': _write('v2_view_delete_unknown')});

        await _client(dio, hasV2: hasV2).views.delete(_studio, _board);
      });

      test('a project that is gone is not a deleted view', () async {
        final dio = fakeDio({
          '$base$board': _write('v2_project_delete_unknown'),
        });

        await expectLater(
          _client(dio, hasV2: hasV2).views.delete(_studio, _board),
          throwsA(isA<NotFound>().having((f) => f.code, 'code', 3001)),
        );
      });
    });
  }
}
