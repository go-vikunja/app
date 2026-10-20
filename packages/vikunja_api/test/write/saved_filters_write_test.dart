import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';

// The answers were captured by tool/capture_saved_filter_fixtures.dart:
// "Urgent open" 582 created by v1 (later "Urgent"), "Today" 583 created by v2
// (later "This week"). Each capture keeps the body it sent as `sent`.
const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';
const _urgent = 582;
const _today = 583;

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

Object? _sentFilters(String name) =>
    (_sent(name)! as Map<String, Object?>)['filters'];

Map<String, Object?> _lastBody(Dio dio) =>
    adapterOf(dio).decodedBodies.last! as Map<String, Object?>;

String _contentType(Dio dio) =>
    adapterOf(dio).requests.last.headers['content-type'] as String;

Matcher _domainError(int status, int code) => isA<DomainError>()
    .having((f) => f.statusCode, 'status', status)
    .having((f) => f.code, 'code', code);

const _urgentDraft = SavedFilterDraft(
  title: 'Urgent open',
  description: 'Open and urgent',
  filter: ViewFilter(
    filter: 'done = false && priority >= 3',
    sortBy: ['due_date'],
    orderBy: ['asc'],
    includeNulls: true,
  ),
);

const _thisWeek = SavedFilterDraft(
  title: 'This week',
  description: 'Due within the week',
  filter: ViewFilter(filter: 'due_date < now/w+1w', includeNulls: true),
);

SavedFilterDraft _refused(String filter) => SavedFilterDraft(
  title: 'Refused',
  filter: ViewFilter(filter: filter),
);

void main() {
  group('create', () {
    test('v1 puts every field, the filter with all its keys', () async {
      final dio = fakeDio({'$_v1/filters': _write('v1_saved_filter_create')});

      final created = await _client(
        dio,
        hasV2: false,
      ).savedFilters.create(_urgentDraft);

      expect(_calls(dio), ['PUT $_v1/filters']);
      expect(adapterOf(dio).decodedBodies, [_sent('v1_saved_filter_create')]);
      expect(created.id, _urgent);
      expect(created.pseudoProjectId, -583);
      expect(created.title, 'Urgent open');
      expect(created.description, 'Open and urgent');
      expect(created.filter, _urgentDraft.filter);
      expect(created.isFavorite, isFalse);
      expect(created.timezone, '');
      expect(created.updated, DateTime.utc(2026, 10, 20, 8, 43, 40, 26, 201));
    });

    test('v2 posts the same body', () async {
      final dio = fakeDio({'$_v2/filters': _write('v2_saved_filter_create')});

      final created = await _client(dio, hasV2: true).savedFilters.create(
        const SavedFilterDraft(
          title: 'Today',
          filter: ViewFilter(
            filter: 'due_date >= now/d && due_date < now/d+1d',
          ),
        ),
      );

      expect(_calls(dio), ['POST $_v2/filters']);
      expect(adapterOf(dio).decodedBodies, [_sent('v2_saved_filter_create')]);
      expect(created.id, _today);
      expect(created.filter.filter, 'due_date >= now/d && due_date < now/d+1d');
    });

    final refusals = <String, ({String filter, Matcher matcher})>{
      'v2_saved_filter_create_invalid_field': (
        filter: 'dueDate < now',
        matcher: _domainError(400, 4016),
      ),
      'v2_saved_filter_create_invalid_value': (
        filter: 'done = yes',
        matcher: _domainError(400, 4019),
      ),
      'v2_saved_filter_create_invalid_syntax': (
        filter: 'done = true &&',
        matcher: _domainError(400, 4024),
      ),
    };
    for (final MapEntry(key: name, value: (:filter, :matcher))
        in refusals.entries) {
      test('a filter the server refuses: $name', () async {
        final dio = fakeDio({'$_v2/filters': _write(name)});

        await expectLater(
          _client(dio, hasV2: true).savedFilters.create(_refused(filter)),
          throwsA(matcher),
        );
        expect(_lastBody(dio)['filters'], _sentFilters(name));
      });
    }

    test('v1 refuses a filter without any key set with 2002', () async {
      final dio = fakeDio({
        '$_v1/filters': _write('v1_saved_filter_create_empty'),
      });

      await expectLater(
        _client(dio, hasV2: false).savedFilters.create(_refused('')),
        throwsA(isA<ValidationFailed>().having((f) => f.code, 'code', 2002)),
      );
    });

    test('an empty filter text with every key sent is accepted', () async {
      final dio = fakeDio({
        '$_v2/filters': _write('v2_saved_filter_create_empty'),
      });

      final created = await _client(
        dio,
        hasV2: true,
      ).savedFilters.create(_refused(''));

      expect(
        _lastBody(dio)['filters'],
        _sentFilters('v2_saved_filter_create_empty'),
      );
      expect(created.filter, const ViewFilter());
    });
  });

  group('read', () {
    test('v1 and v2 read the filter with its definition; v2 adds the '
        'owner and the permission', () async {
      final v1 = fakeDio({
        '$_v1/filters/$_urgent': _write('v1_saved_filter_read'),
      });
      final v2 = fakeDio({
        '$_v2/filters/$_today': _write('v2_saved_filter_read'),
      });

      final urgent = await _client(v1, hasV2: false).savedFilters.read(_urgent);
      final today = await _client(v2, hasV2: true).savedFilters.read(_today);

      expect(_calls(v1), ['GET $_v1/filters/$_urgent']);
      expect(_calls(v2), ['GET $_v2/filters/$_today']);
      expect(urgent.filter, _urgentDraft.filter);
      expect(urgent.updated, DateTime.utc(2026, 10, 20, 8, 43, 40));
      expect(today.title, 'Today');
      expect(today.filter.includeNulls, isFalse);
    });

    test('the read client reads the same way', () async {
      final dio = fakeDio({
        '$_v2/filters/$_today': _write('v2_saved_filter_read'),
      });

      final today = await createReadClient(
        dio: dio,
        connection: testConnection(),
      ).savedFilters.read(_today);

      expect(today.id, _today);
      expect(today.filter.filter, 'due_date >= now/d && due_date < now/d+1d');
    });

    test('an unknown id is NotFound 11001', () async {
      final dio = fakeDio({
        '$_v2/filters/999999': _write('v2_saved_filter_read_unknown'),
      });

      await expectLater(
        _client(dio, hasV2: true).savedFilters.read(999999),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 11001)),
      );
    });

    test('a timezone the server sends is kept', () async {
      final dio = fakeDio({
        '$_v2/filters/$_today': json({
          'id': _today,
          'title': 'Today',
          'filters': {
            'filter': 'due_date < now/d',
            'filter_timezone': 'Europe/Berlin',
          },
        }),
      });

      final today = await _client(dio, hasV2: true).savedFilters.read(_today);

      expect(today.timezone, 'Europe/Berlin');
      expect(today.filter.filter, 'due_date < now/d');
    });
  });

  group('v2 update', () {
    test('sends a merge-patch with every field and returns the filter as '
        'stored', () async {
      final dio = fakeDio({
        '$_v2/filters/$_today': _write('v2_saved_filter_update'),
      });

      final updated = await _client(
        dio,
        hasV2: true,
      ).savedFilters.update(_today, _thisWeek);

      expect(_calls(dio), ['PATCH $_v2/filters/$_today']);
      expect(_contentType(dio), 'application/merge-patch+json');
      expect(adapterOf(dio).decodedBodies, [_sent('v2_saved_filter_update')]);
      expect(updated.title, 'This week');
      expect(updated.filter, _thisWeek.filter);
      expect(
        updated.updated!.isAfter(DateTime.utc(2026, 10, 20, 8, 43, 41)),
        isTrue,
      );
    });

    test('reads the filter when nothing changed (304)', () async {
      final dio = fakeDio({
        '$_v2/filters/$_today': _byMethod({
          'PATCH': _write('v2_saved_filter_update_unchanged'),
          'GET': _write('v2_saved_filter_read'),
        }),
      });

      final read = await _client(
        dio,
        hasV2: true,
      ).savedFilters.update(_today, _thisWeek);

      expect(_calls(dio), [
        'PATCH $_v2/filters/$_today',
        'GET $_v2/filters/$_today',
      ]);
      expect(read.id, _today);
    });

    test('a favourite sends only the flag', () async {
      final dio = fakeDio({
        '$_v2/filters/$_today': _write('v2_saved_filter_favorite'),
      });

      final favourite = await _client(
        dio,
        hasV2: true,
      ).savedFilters.setFavorite(_today, favorite: true);

      expect(adapterOf(dio).decodedBodies, [_sent('v2_saved_filter_favorite')]);
      expect(favourite.isFavorite, isTrue);
      expect(favourite.title, 'This week');
    });
  });

  group('v1 update', () {
    test('reads the filter and posts it back whole with the draft '
        'overlaid', () async {
      final dio = fakeDio({
        '$_v1/filters/$_urgent': _byMethod({
          'GET': _write('v1_saved_filter_update_read'),
          'POST': _write('v1_saved_filter_update'),
        }),
      });

      final updated = await _client(dio, hasV2: false).savedFilters.update(
        _urgent,
        const SavedFilterDraft(
          title: 'Urgent',
          filter: ViewFilter(filter: 'priority >= 4'),
        ),
      );

      expect(_calls(dio), [
        'GET $_v1/filters/$_urgent',
        'POST $_v1/filters/$_urgent',
      ]);
      expect(_lastBody(dio), _sent('v1_saved_filter_update'));
      expect(updated.title, 'Urgent');
      expect(updated.description, '');
      expect(updated.filter, const ViewFilter(filter: 'priority >= 4'));
    });

    test('a favourite keeps everything else', () async {
      final dio = fakeDio({
        '$_v1/filters/$_urgent': _byMethod({
          'GET': _write('v1_saved_filter_favorite_read'),
          'POST': _write('v1_saved_filter_favorite'),
        }),
      });

      final favourite = await _client(
        dio,
        hasV2: false,
      ).savedFilters.setFavorite(_urgent, favorite: true);

      final sent = _lastBody(dio);
      expect(sent, _sent('v1_saved_filter_favorite'));
      expect(sent, containsPair('title', 'Urgent'));
      expect(favourite.isFavorite, isTrue);
      expect(favourite.filter.filter, 'priority >= 4');
    });
  });

  group('delete', () {
    test('v1 and v2 delete; one gone already counts as deleted', () async {
      final v1 = fakeDio({
        '$_v1/filters/$_urgent': _write('v1_saved_filter_delete'),
      });
      final v2 = fakeDio({
        '$_v2/filters/$_today': sequence([
          _write('v2_saved_filter_delete'),
          _write('v2_saved_filter_delete_unknown'),
        ]),
      });

      await _client(v1, hasV2: false).savedFilters.delete(_urgent);
      await _client(v2, hasV2: true).savedFilters.delete(_today);
      await _client(v2, hasV2: true).savedFilters.delete(_today);

      expect(_calls(v1), ['DELETE $_v1/filters/$_urgent']);
      expect(_calls(v2), [
        'DELETE $_v2/filters/$_today',
        'DELETE $_v2/filters/$_today',
      ]);
    });

    test('another 404 is thrown', () async {
      final dio = fakeDio({'$_v2/filters/$_today': status(404)});

      await expectLater(
        _client(dio, hasV2: true).savedFilters.delete(_today),
        throwsA(isA<NotFound>()),
      );
    });
  });
}
