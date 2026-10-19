import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';

// The answers were captured by tool/capture_ordering_fixtures.dart: Ordering
// 1034 and Elsewhere 1035 at the top level, Child 1036 under Ordering (colour
// 4a90e2, identifier CHI, a description) with a grandchild, and an archived
// project. The v1 update moved Child under Elsewhere, the v2 patch back.
const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';
const _ordering = 1034;
const _elsewhere = 1035;
const _child = 1036;

ProjectsWritePort _projects(Dio dio, {required bool hasV2}) =>
    createWriteClient(
      dio: dio,
      connection: testConnection(hasV2: hasV2),
    ).projects;

List<String> _calls(Dio dio) => [
  for (final request in adapterOf(dio).requests)
    '${request.method} ${request.uri}',
];

FakeRoute _byMethod(Map<String, FakeRoute> routes) =>
    (request) => (routes[request.method] ?? refused)(request);

FakeRoute _write(String name) => capturedFixture('write/$name');

Map<String, Object?> _capturedBody(String name) =>
    jsonDecode(fixtureJson('write/$name.json')['body']! as String)
        as Map<String, Object?>;

void main() {
  group('v2 project move', () {
    test('send a merge-patch with the position and the parent and return '
        'the project as stored', () async {
      final dio = fakeDio({
        '$_v2/projects/$_child': _write('v2_project_move_2.7.0'),
      });

      final project = await _projects(
        dio,
        hasV2: true,
      ).move(_child, position: 3000.25, parentProjectId: _ordering);

      expect(_calls(dio), ['PATCH $_v2/projects/$_child']);
      expect(
        adapterOf(dio).requests.single.headers['content-type'],
        'application/merge-patch+json',
      );
      expect(adapterOf(dio).decodedBodies, [
        {'position': 3000.25, 'parent_project_id': _ordering},
      ]);
      expect(project.id, _child);
      expect(project.parentProjectId, _ordering);
      expect(project.position, 3000.25);
      expect(project.title, 'Child');
      expect(project.hexColor, '4a90e2');
      expect(project.identifier, 'CHI');
      expect(project.description, '<p>Nested</p>');
      expect(project.views, hasLength(4));
    });

    test('send parent 0 for the top level', () async {
      final dio = fakeDio({
        '$_v2/projects/$_child': _write('v2_project_move_2.7.0'),
      });

      await _projects(
        dio,
        hasV2: true,
      ).move(_child, position: 99999999, parentProjectId: 0);

      expect(adapterOf(dio).decodedBodies, [
        {'position': 99999999, 'parent_project_id': 0},
      ]);
    });

    test('read the project when nothing changed (304)', () async {
      final dio = fakeDio({
        '$_v2/projects/$_child': _byMethod({
          'PATCH': _write('v2_project_move_unchanged_2.7.0'),
          'GET': _write('v2_project_2.7.0'),
        }),
      });

      final project = await _projects(
        dio,
        hasV2: true,
      ).move(_child, position: 2500.5, parentProjectId: _elsewhere);

      expect(_calls(dio), [
        'PATCH $_v2/projects/$_child',
        'GET $_v2/projects/$_child',
      ]);
      expect(project.parentProjectId, _elsewhere);
      expect(project.position, 2500.5);
    });

    final refusals = <String, Matcher>{
      'v2_project_move_own_parent': isA<DomainError>()
          .having((f) => f.statusCode, 'status', 412)
          .having((f) => f.code, 'code', 3010),
      'v2_project_move_cycle': isA<DomainError>().having(
        (f) => f.code,
        'code',
        3011,
      ),
      'v2_project_move_archived_parent': isA<DomainError>().having(
        (f) => f.code,
        'code',
        3008,
      ),
      'v2_project_move_pseudo_parent': isA<DomainError>().having(
        (f) => f.code,
        'code',
        3009,
      ),
      'v2_project_move_unknown_parent': isA<NotFound>().having(
        (f) => f.code,
        'code',
        3001,
      ),
      'v2_project_move_unknown': isA<NotFound>().having(
        (f) => f.code,
        'code',
        3001,
      ),
      'v2_project_move_not_admin': isA<Forbidden>().having(
        (f) => f.code,
        'code',
        1,
      ),
      'v2_project_move_read_only': isA<Forbidden>().having(
        (f) => f.code,
        'code',
        isNull,
      ),
    };
    for (final MapEntry(key: name, value: matcher) in refusals.entries) {
      test('$name is refused as captured, without a read', () async {
        final dio = fakeDio({'$_v2/projects/$_child': _write('${name}_2.7.0')});

        await expectLater(
          _projects(
            dio,
            hasV2: true,
          ).move(_child, position: 3000.25, parentProjectId: _ordering),
          throwsA(matcher),
        );
        expect(_calls(dio), ['PATCH $_v2/projects/$_child']);
      });
    }
  });

  group('v1 project move', () {
    test('read the project and post it back whole with the position and the '
        'parent changed', () async {
      final dio = fakeDio({
        '$_v1/projects/$_child': _byMethod({
          'GET': _write('v1_project_2.7.0'),
          'POST': _write('v1_project_move_2.7.0'),
        }),
      });

      final project = await _projects(
        dio,
        hasV2: false,
      ).move(_child, position: 2500.5, parentProjectId: _elsewhere);

      expect(_calls(dio), [
        'GET $_v1/projects/$_child',
        'POST $_v1/projects/$_child',
      ]);
      final sent = adapterOf(dio).decodedBodies.last! as Map<String, Object?>;
      expect(sent, {
        ..._capturedBody('v1_project_2.7.0'),
        'position': 2500.5,
        'parent_project_id': _elsewhere,
      });
      expect(sent, containsPair('title', 'Child'));
      expect(sent, containsPair('hex_color', '4a90e2'));
      expect(sent, containsPair('identifier', 'CHI'));
      expect(sent, containsPair('description', '<p>Nested</p>'));
      expect(sent, containsPair('is_favorite', false));
      expect(sent, containsPair('is_archived', false));
      expect(project.parentProjectId, _elsewhere);
      expect(project.position, 2500.5);
      expect(project.hexColor, '4a90e2');
    });

    test('keep a favourite', () async {
      final dio = fakeDio({
        '$_v1/projects/$_ordering': _byMethod({
          'GET': json({
            'id': _ordering,
            'title': 'Ordering',
            'description': '',
            'identifier': 'ORD',
            'hex_color': 'e8b04a',
            'parent_project_id': 0,
            'is_archived': false,
            'is_favorite': true,
            'position': 67764224,
          }),
          'POST': _write('v1_project_move_2.7.0'),
        }),
      });

      await _projects(
        dio,
        hasV2: false,
      ).move(_ordering, position: 1000, parentProjectId: 0);

      expect(adapterOf(dio).decodedBodies.last, {
        'id': _ordering,
        'title': 'Ordering',
        'description': '',
        'identifier': 'ORD',
        'hex_color': 'e8b04a',
        'parent_project_id': 0,
        'is_archived': false,
        'is_favorite': true,
        'position': 1000,
      });
    });

    test('a cycle fails with 3011 after the read', () async {
      final dio = fakeDio({
        '$_v1/projects/$_ordering': _byMethod({
          'GET': json({'id': _ordering, 'title': 'Ordering', 'position': 1}),
          'POST': _write('v1_project_move_cycle_2.7.0'),
        }),
      });

      await expectLater(
        _projects(
          dio,
          hasV2: false,
        ).move(_ordering, position: 1, parentProjectId: 1037),
        throwsA(isA<DomainError>().having((f) => f.code, 'code', 3011)),
      );
    });

    test('a project that is gone fails on the read; nothing is '
        'posted', () async {
      final dio = fakeDio({
        '$_v1/projects/$_child': _byMethod({
          'GET': json({
            'code': 3001,
            'message': 'This project does not exist.',
          }, status: 404),
        }),
      });

      await expectLater(
        _projects(
          dio,
          hasV2: false,
        ).move(_child, position: 1, parentProjectId: 0),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 3001)),
      );
      expect(_calls(dio), ['GET $_v1/projects/$_child']);
    });
  });

  for (final hasV2 in [true, false]) {
    final version = hasV2 ? 'v2' : 'v1';

    group('$version project move positions', () {
      for (final position in [0.09, 0.0, -5.0, double.nan, double.infinity]) {
        test('$position is refused before any request', () async {
          final dio = fakeDio({});

          await expectLater(
            _projects(
              dio,
              hasV2: hasV2,
            ).move(_child, position: position, parentProjectId: _ordering),
            throwsArgumentError,
          );
          expect(adapterOf(dio).requests, isEmpty);
        });
      }

      test('0.1 is sent', () async {
        final base = hasV2 ? _v2 : _v1;
        final dio = fakeDio({
          '$base/projects/$_child': _byMethod({
            'PATCH': _write('v2_project_move_2.7.0'),
            'GET': _write('v1_project_2.7.0'),
            'POST': _write('v1_project_move_2.7.0'),
          }),
        });

        await _projects(
          dio,
          hasV2: hasV2,
        ).move(_child, position: 0.1, parentProjectId: _ordering);

        expect((adapterOf(dio).decodedBodies.last! as Map)['position'], 0.1);
      });
    });
  }
}
