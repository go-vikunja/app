import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';

// The answers were captured by tool/capture_sharing_fixtures.dart: the owner
// (145) made label 107 on v2 and label 108 on v1 with the colour `ABC`, which
// 2.7.0 still takes, and a label titled "2026" (109); the member (146) sees
// none of them. The member's projects: their Inbox (416), the owner's
// project 418 shared with write permission and its child 419.
const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';
const _v2Label = 107;
const _v1Label = 108;
const _numericLabel = 109;
const _shared = 418;

FakeRoute _captured(String name) => capturedFixture('sharing/${name}_2.7.0');

FakeRoute _byMethod(Map<String, FakeRoute> routes) =>
    (request) => (routes[request.method] ?? refused)(request);

List<String> _calls(Dio dio) => [
  for (final request in adapterOf(dio).requests)
    '${request.method} ${request.uri}',
];

LabelsWritePort _labels(Dio dio, String version) => createWriteClient(
  dio: dio,
  connection: testConnection(hasV2: version == 'v2'),
).labels;

VikunjaReadClient _read(Dio dio, String version) => createReadClient(
  dio: dio,
  connection: testConnection(hasV2: version == 'v2'),
);

FakeRoute _labelList(String version, List<Map<String, Object?>> labels) =>
    json(switch (version) {
      'v2' => {
        'items': labels,
        'total': labels.length,
        'page': 1,
        'per_page': 50,
        'total_pages': 1,
      },
      _ => labels,
    });

void main() {
  group('v2 label update', () {
    test('a merge-patch of the changed fields, the answer stored', () async {
      final dio = fakeDio({
        '$_v2/labels/$_v2Label': _captured('v2_label_update'),
      });

      final label = await _labels(dio, 'v2').update(
        _v2Label,
        const LabelChanges(title: 'Renamed label', hexColor: '#1973ff'),
      );

      expect(_calls(dio), ['PATCH $_v2/labels/$_v2Label']);
      expect(
        adapterOf(dio).requests.single.headers['content-type'],
        'application/merge-patch+json',
      );
      expect(adapterOf(dio).decodedBodies, [
        {'title': 'Renamed label', 'hex_color': '1973ff'},
      ]);
      expect(label.id, _v2Label);
      expect(label.title, 'Renamed label');
      expect(label.hexColor, '1973ff');
      expect(label.description, '<p>Old</p>');
      expect(label.createdBy?.id, 145);
    });

    test('unchanged answers 304 and is read', () async {
      final dio = fakeDio({
        '$_v2/labels/$_v2Label': _byMethod({
          'PATCH': _captured('v2_label_update_unchanged'),
          'GET': _captured('v2_label_read'),
        }),
      });

      final label = await _labels(
        dio,
        'v2',
      ).update(_v2Label, const LabelChanges(title: 'Renamed label'));

      expect(_calls(dio), [
        'PATCH $_v2/labels/$_v2Label',
        'GET $_v2/labels/$_v2Label',
      ]);
      expect(label.title, 'Renamed label');
    });

    test('a cleared colour is sent empty', () async {
      final dio = fakeDio({
        '$_v2/labels/$_v2Label': _captured('v2_label_update'),
      });

      await _labels(
        dio,
        'v2',
      ).update(_v2Label, const LabelChanges(hexColor: '', description: ''));

      expect(adapterOf(dio).decodedBodies, [
        {'description': '', 'hex_color': ''},
      ]);
    });

    test('a title above the limit is refused', () async {
      final dio = fakeDio({
        '$_v2/labels/$_v2Label': _captured('v2_label_update_too_long'),
      });

      await expectLater(
        _labels(dio, 'v2').update(_v2Label, LabelChanges(title: 'x' * 251)),
        throwsA(
          isA<ValidationFailed>().having((f) => f.fieldErrors.keys, 'fields', [
            'title',
          ]),
        ),
      );
    });

    test("someone else's label stays refused when it is listed", () async {
      final dio = fakeDio({
        '$_v2/labels/$_v2Label': _captured('v2_label_update_not_creator'),
        '$_v2/labels?q=$_v2Label': _labelList('v2', [
          {'id': _v2Label, 'title': 'Renamed label'},
        ]),
      });

      await expectLater(
        _labels(dio, 'v2').update(_v2Label, const LabelChanges(title: 'x')),
        throwsA(isA<Forbidden>().having((f) => f.code, 'code', isNull)),
      );
      expect(_calls(dio), [
        'PATCH $_v2/labels/$_v2Label',
        'GET $_v2/labels?q=$_v2Label',
      ]);
    });

    test('a label that is gone is a not found', () async {
      final dio = fakeDio({
        '$_v2/labels/$_v2Label': _captured('v2_label_update_gone'),
        '$_v2/labels?q=$_v2Label': _labelList('v2', []),
      });

      await expectLater(
        _labels(dio, 'v2').update(_v2Label, const LabelChanges(title: 'x')),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 8002)),
      );
    });
  });

  group('v1 label update', () {
    test("a read posted back whole keeps another client's colour", () async {
      final dio = fakeDio({
        '$_v1/labels/$_v1Label': _byMethod({
          'GET': _captured('v1_label_read'),
          'POST': _captured('v1_label_update'),
        }),
      });

      final label = await _labels(
        dio,
        'v1',
      ).update(_v1Label, const LabelChanges(title: 'Still odd'));

      expect(_calls(dio), [
        'GET $_v1/labels/$_v1Label',
        'POST $_v1/labels/$_v1Label',
      ]);
      final sent = adapterOf(dio).decodedBodies.last! as Map<String, Object?>;
      expect(sent['title'], 'Still odd');
      expect(sent['hex_color'], 'ABC');
      expect(sent['description'], '<p>Kept</p>');
      expect(label.title, 'Still odd');
      expect(label.description, '<p>Kept</p>');
    });

    test('a title above the limit is refused', () async {
      final dio = fakeDio({
        '$_v1/labels/$_v1Label': _byMethod({
          'GET': _captured('v1_label_read'),
          'POST': _captured('v1_label_update_too_long'),
        }),
      });

      await expectLater(
        _labels(dio, 'v1').update(_v1Label, LabelChanges(title: 'x' * 251)),
        throwsA(
          isA<ValidationFailed>().having((f) => f.code, 'code', 2002).having(
            (f) => f.fieldErrors.keys,
            'fields',
            ['title'],
          ),
        ),
      );
    });

    test('a label gone or out of sight is a not found', () async {
      for (final fixture in [
        'v1_label_read_gone',
        'v1_label_read_not_visible',
      ]) {
        final dio = fakeDio({
          '$_v1/labels/$_v1Label': _captured(fixture),
          '$_v1/labels?s=$_v1Label': _captured('v1_labels_search_digits'),
        });

        await expectLater(
          _labels(dio, 'v1').update(_v1Label, const LabelChanges(title: 'x')),
          throwsA(isA<NotFound>().having((f) => f.code, 'code', 8002)),
          reason: fixture,
        );
        expect(adapterOf(dio).requests.map((r) => r.method), ['GET', 'GET']);
      }
    });

    test("someone else's visible label is refused", () async {
      final dio = fakeDio({
        '$_v1/labels/$_v1Label': _byMethod({
          'GET': _captured('v1_label_read'),
          'POST': _captured('v1_label_update_not_creator'),
        }),
        '$_v1/labels?s=$_v1Label': _labelList('v1', [
          {'id': _v1Label, 'title': 'Odd colour'},
        ]),
      });

      await expectLater(
        _labels(dio, 'v1').update(_v1Label, const LabelChanges(title: 'x')),
        throwsA(isA<Forbidden>()),
      );
    });
  });

  for (final version in ['v1', 'v2']) {
    final base = version == 'v2' ? _v2 : _v1;
    final label = version == 'v2' ? _v2Label : _v1Label;

    test('$version label delete, again counts as deleted', () async {
      final dio = fakeDio({
        '$base/labels/$label': sequence([
          _captured('${version}_label_delete'),
          _captured('${version}_label_delete_gone'),
        ]),
      });
      final labels = _labels(dio, version);

      await labels.delete(label);
      await labels.delete(label);

      expect(_calls(dio), [
        'DELETE $base/labels/$label',
        'DELETE $base/labels/$label',
      ]);
    });

    test('$version label delete by someone else is refused', () async {
      final dio = fakeDio({
        '$base/labels/$label': _captured(
          version == 'v2'
              ? 'v2_label_update_not_creator'
              : 'v1_label_update_not_creator',
        ),
      });

      await expectLater(
        _labels(dio, version).delete(label),
        throwsA(isA<Forbidden>()),
      );
    });

    test('$version empty label changes are a read', () async {
      final dio = fakeDio({
        '$base/labels/$label': _captured('${version}_label_read'),
      });

      await _labels(dio, version).update(label, const LabelChanges());

      expect(_calls(dio), ['GET $base/labels/$label']);
    });

    group('$version label search', () {
      test('a numeric search is matched over every label', () async {
        final dio = fakeDio({
          '$base/labels?page=1': _captured('${version}_labels_all'),
        });

        final page = await _read(dio, version).labels.list(search: ' 2026 ');

        expect(_calls(dio), ['GET $base/labels?page=1']);
        expect(page.items.map((label) => label.id), [_numericLabel]);
        expect(page.totalPages, 1);
        expect(page.hasMore, isFalse);
      });

      test('a search with a numeric part is matched as one text', () async {
        final dio = fakeDio({
          '$base/labels?page=1': _captured('${version}_labels_all'),
        });

        final odd = await _read(dio, version).labels.list(search: 'odd,1');
        final kept = await _read(dio, version).labels.list(search: '-5,kept');

        expect(_calls(dio), [
          'GET $base/labels?page=1',
          'GET $base/labels?page=1',
        ]);
        expect(odd.items, isEmpty);
        expect(kept.items, isEmpty);
      });

      test('a later page of a numeric search is empty', () async {
        final dio = fakeDio({
          '$base/labels?page=1': _captured('${version}_labels_all'),
        });

        final page = await _read(
          dio,
          version,
        ).labels.list(search: '2026', page: 2);

        expect(page.items, isEmpty);
        expect(adapterOf(dio).requests, isEmpty);
      });

      test('a text search still asks the server', () async {
        final parameter = version == 'v2' ? 'q' : 's';
        final dio = fakeDio({
          '$base/labels?$parameter=2026+plans&page=1': _labelList(version, []),
        });

        await _read(dio, version).labels.list(search: '2026 plans');

        expect(_calls(dio), ['GET $base/labels?$parameter=2026+plans&page=1']);
      });
    });

    group('$version user search', () {
      test('the exact username in any case', () async {
        final url = version == 'v2'
            ? '$base/users?q=fixturemember'
            : '$base/users?s=FIXTUREMEMBER';
        final dio = fakeDio({url: _captured('${version}_users_search')});

        final users = await _read(dio, version).users.searchUsers(
          version == 'v2' ? 'fixturemember' : ' FIXTUREMEMBER ',
        );

        expect(_calls(dio), ['GET $url']);
        expect(users, const [User(id: 146, username: 'fixturemember')]);
      });

      test('nothing found', () async {
        final parameter = version == 'v2' ? 'q' : 's';
        final dio = fakeDio({
          '$base/users?$parameter=nobody-at-all': _captured(
            '${version}_users_search_none',
          ),
        });

        final users = await _read(
          dio,
          version,
        ).users.searchUsers('nobody-at-all');

        expect(users, isEmpty);
      });

      test('a blank query asks nothing', () async {
        final dio = fakeDio({});

        expect(await _read(dio, version).users.searchUsers('  '), isEmpty);
        expect(adapterOf(dio).requests, isEmpty);
      });

      test('an email in an answer is dropped', () async {
        final parameter = version == 'v2' ? 'q' : 's';
        final user = {
          'id': 3,
          'username': 'c',
          'name': 'Cleo',
          'email': 'c@example.invalid',
        };
        final dio = fakeDio({
          '$base/users?$parameter=c': json(switch (version) {
            'v2' => {
              'items': [user],
              'total': 1,
              'page': 1,
              'per_page': 1,
              'total_pages': 1,
            },
            _ => [user],
          }),
        });

        final users = await _read(dio, version).users.searchUsers('c');

        expect(users.single.email, isNull);
        expect(users.single.name, 'Cleo');
      });
    });

    group('$version project permissions', () {
      test('the sync list asks for them and gets one per project', () async {
        final url =
            '$base/projects?is_archived=true&page=1&per_page=50'
            '&expand=permissions';
        final dio = fakeDio({url: _captured('${version}_projects_expanded')});

        final page = await _read(
          dio,
          version,
        ).projects.list(includeArchived: true, perPage: 50);

        expect(_calls(dio), ['GET $url']);
        expect(
          {for (final p in page.items) p.id: p.maxPermission},
          {
            416: Permission.admin,
            _shared: Permission.write,
            419: Permission.write,
            -158: Permission.admin,
          },
        );
      });

      test('without the expand every permission is unknown', () async {
        final dio = fakeDio({
          '$base/projects?is_archived=true&page=1&per_page=50&expand=permissions':
              _captured('${version}_projects_unexpanded'),
        });

        final page = await _read(
          dio,
          version,
        ).projects.list(includeArchived: true, perPage: 50);

        expect(page.items, isNotEmpty);
        expect(page.items.map((p) => p.maxPermission).toSet(), {null});
      });

      test('a single read carries it (v1 in a header)', () async {
        final dio = fakeDio({
          '$base/projects/$_shared': _captured('${version}_project_read'),
        });

        final project = await _read(dio, version).projects.read(_shared);

        expect(project.maxPermission, Permission.write);
        expect(project.owner?.id, 145);
      });
    });
  }

  test('the v1 header wins over a body permission (0 for "not computed" '
      'before 2.6), null stays null', () async {
    final dio = fakeDio({
      '$_v1/projects/1': (_) => ResponseBody.fromString(
        '{"id":1,"title":"p","max_permission":0}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
          'x-max-permission': ['2'],
        },
      ),
      '$_v1/projects/2': json({'id': 2, 'title': 'p', 'max_permission': null}),
    });

    final read = _read(dio, 'v1').projects;

    expect((await read.read(1)).maxPermission, Permission.admin);
    expect((await read.read(2)).maxPermission, isNull);
  });

  test('a project from a write answer has no permission', () async {
    final dio = fakeDio({
      '$_v2/projects': json({
        'id': 5,
        'title': 'New',
        'max_permission': 0,
      }, status: 201),
    });

    final project = await createWriteClient(
      dio: dio,
      connection: testConnection(),
    ).projects.create(const NewProject(title: 'New'));

    expect(project.maxPermission, isNull);
  });
}
