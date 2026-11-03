/// Pins the REST contract of every remote data source: verb, path, query
/// parameters, request body and the mapper applied to the response.
///
/// Transport behaviour lives in `test/core/network/`; DTO field mapping lives
/// in `test/data/models/`. Nothing here re-tests either.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/network/remote_data_source.dart';
import 'package:vikunja_app/data/data_sources/bucket_data_source.dart';
import 'package:vikunja_app/data/data_sources/label_data_source.dart';
import 'package:vikunja_app/data/data_sources/project_data_source.dart';
import 'package:vikunja_app/data/data_sources/project_view_data_source.dart';
import 'package:vikunja_app/data/data_sources/server_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_comment_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_label_bulk_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_label_data_source.dart';
import 'package:vikunja_app/data/data_sources/user_data_source.dart';
import 'package:vikunja_app/data/models/bucket_dto.dart';
import 'package:vikunja_app/data/models/label_dto.dart';
import 'package:vikunja_app/data/models/project_dto.dart';
import 'package:vikunja_app/data/models/project_view_dto.dart';
import 'package:vikunja_app/data/models/task_comment_dto.dart';
import 'package:vikunja_app/data/models/task_dto.dart';
import 'package:vikunja_app/data/models/task_label_dto.dart';
import 'package:vikunja_app/data/models/user_dto.dart';

import '../../helpers/json_fixtures.dart';
import '../../helpers/recording_client.dart';

void main() {
  late RecordingClient client;

  setUp(() => client = RecordingClient());

  group('RemoteDataSource.convertList', () {
    test('applies the mapper to every element', () {
      final source = RemoteDataSource(client);

      final result = source.convertList([
        taskJson(id: 1),
        taskJson(id: 2),
      ], (json) => TaskDto.fromJson(json));

      expect(result.map((t) => t.id), [1, 2]);
    });

    test('returns an empty list for an empty input', () {
      expect(
        RemoteDataSource(
          client,
        ).convertList([], (json) => TaskDto.fromJson(json)),
        isEmpty,
      );
    });

    test('exposes the client it was built with', () {
      expect(RemoteDataSource(client).client, same(client));
    });
  });

  group('ProjectDataSource', () {
    late ProjectDataSource source;
    setUp(() => source = ProjectDataSource(client));

    test('getAll pages through GET /projects', () async {
      client.nextBody = [projectJson(id: 1)];

      final response = await source.getAll(page: 3);

      expect(client.lastCall.verb, 'GET');
      expect(client.lastCall.url, '/projects');
      expect(client.lastCall.queryParameters, {
        'page': ['3'],
      });
      expect(response.toSuccess().body.single.id, 1);
    });

    test('getAll defaults to the first page', () async {
      client.nextBody = <dynamic>[];

      await source.getAll();

      expect(client.lastCall.queryParameters, {
        'page': ['1'],
      });
    });

    test('get fetches a single project by id', () async {
      client.nextBody = projectJson(id: 7);

      final response = await source.get(7);

      expect(client.lastCall.verb, 'GET');
      expect(client.lastCall.url, '/projects/7');
      expect(response.toSuccess().body.id, 7);
    });

    test('create PUTs the serialised project', () async {
      client.nextBody = projectJson(id: 1);

      await source.create(ProjectDto(title: 'New'));

      expect(client.lastCall.verb, 'PUT');
      expect(client.lastCall.url, '/projects');
      expect(client.lastCall.body['title'], 'New');
    });

    test('update POSTs to the project id', () async {
      client.nextBody = projectJson(id: 4);

      await source.update(ProjectDto(id: 4, title: 'Renamed'));

      expect(client.lastCall.verb, 'POST');
      expect(client.lastCall.url, '/projects/4');
      expect(client.lastCall.body['title'], 'Renamed');
    });
  });

  group('ProjectViewDataSource', () {
    test('update POSTs to the project/view path', () async {
      client.nextBody = projectViewJson(id: 11, projectId: 4);

      await ProjectViewDataSource(
        client,
      ).update(ProjectViewDto.fromJson(projectViewJson(id: 11, projectId: 4)));

      expect(client.lastCall.verb, 'POST');
      expect(client.lastCall.url, '/projects/4/views/11');
      expect(client.lastCall.body['id'], 11);
    });
  });

  group('TaskDataSource', () {
    late TaskDataSource source;
    setUp(() => source = TaskDataSource(client));

    test('add PUTs under the project', () async {
      client.nextBody = taskJson(id: 1);

      await source.add(9, TaskDto(createdBy: null, projectId: 9, title: 'New'));

      expect(client.lastCall.verb, 'PUT');
      expect(client.lastCall.url, '/projects/9/tasks');
      expect(client.lastCall.body['title'], 'New');
    });

    test('update POSTs to the task id', () async {
      client.nextBody = taskJson(id: 3);

      await source.update(TaskDto.fromJson(taskJson(id: 3)));

      expect(client.lastCall.verb, 'POST');
      expect(client.lastCall.url, '/tasks/3');
    });

    test('delete DELETEs the task id', () async {
      await source.delete(3);

      expect(client.lastCall.verb, 'DELETE');
      expect(client.lastCall.url, '/tasks/3');
    });

    test('getTask GETs the task id', () async {
      client.nextBody = taskJson(id: 3);

      final response = await source.getTask(3);

      expect(client.lastCall.verb, 'GET');
      expect(client.lastCall.url, '/tasks/3');
      expect(response.toSuccess().body.id, 3);
    });

    test('getAllByProject GETs the project task list', () async {
      client.nextBody = [taskJson(id: 1)];

      final response = await source.getAllByProject(9, {
        'page': ['2'],
      });

      expect(client.lastCall.url, '/projects/9/tasks');
      expect(client.lastCall.queryParameters, {
        'page': ['2'],
      });
      expect(response.toSuccess().body, hasLength(1));
    });

    test('getAllByProjectView GETs the view task list', () async {
      client.nextBody = <dynamic>[];

      await source.getAllByProjectView(9, 11);

      expect(client.lastCall.url, '/projects/9/views/11/tasks');
      expect(client.lastCall.queryParameters, isNull);
    });

    test('getByFilterString puts the filter first in the query', () async {
      client.nextBody = <dynamic>[];

      await source.getByFilterString('done = false', {
        'page': ['2'],
      });

      expect(client.lastCall.url, '/tasks');
      expect(client.lastCall.queryParameters, {
        'filter': ['done = false'],
        'page': ['2'],
      });
    });

    test('getByFilterString works without extra query parameters', () async {
      client.nextBody = <dynamic>[];

      await source.getByFilterString('done = true');

      expect(client.lastCall.queryParameters, {
        'filter': ['done = true'],
      });
    });
  });

  group('BucketDataSource', () {
    late BucketDataSource source;
    setUp(() => source = BucketDataSource(client));

    BucketDto bucket({int id = 50}) => BucketDto.fromJSON(bucketJson(id: id));

    test('add PUTs under the project view', () async {
      client.nextBody = bucketJson();

      await source.add(9, 11, bucket());

      expect(client.lastCall.verb, 'PUT');
      expect(client.lastCall.url, '/projects/9/views/11/buckets');
      expect(client.lastCall.body['title'], 'Backlog');
    });

    test('update POSTs to the bucket id', () async {
      client.nextBody = bucketJson();

      await source.update(9, 11, bucket(id: 50));

      expect(client.lastCall.verb, 'POST');
      expect(client.lastCall.url, '/projects/9/views/11/buckets/50');
    });

    test('delete DELETEs the bucket id', () async {
      await source.delete(9, 11, 50);

      expect(client.lastCall.verb, 'DELETE');
      expect(client.lastCall.url, '/projects/9/views/11/buckets/50');
    });

    test('getAllByList GETs the view tasks grouped into buckets', () async {
      client.nextBody = [bucketJson(id: 50), bucketJson(id: 51)];

      final response = await source.getAllByList(9, 11, {
        'page': ['1'],
      });

      expect(client.lastCall.verb, 'GET');
      expect(client.lastCall.url, '/projects/9/views/11/tasks');
      expect(response.toSuccess().body.map((b) => b.id), [50, 51]);
    });

    test('updateTaskBucket POSTs the full move payload', () async {
      await source.updateTaskBucket(7, 51, 9, 11);

      expect(client.lastCall.verb, 'POST');
      expect(client.lastCall.url, '/projects/9/views/11/buckets/51/tasks');
      expect(client.lastCall.body, {
        'task_id': 7,
        'bucket_id': 51,
        'project_view_id': 11,
        'project_id': 9,
      });
    });

    test('updateTaskPosition POSTs to the task position endpoint', () async {
      await source.updateTaskPosition(7, 11, 65536.0);

      expect(client.lastCall.verb, 'POST');
      expect(client.lastCall.url, '/tasks/7/position');
      expect(client.lastCall.body, {
        'position': 65536.0,
        'project_view_id': 11,
        'task_id': 7,
      });
    });
  });

  group('LabelDataSource', () {
    late LabelDataSource source;
    setUp(() => source = LabelDataSource(client));

    test('getAll without a query hits the bare labels endpoint', () async {
      client.nextBody = [labelJson()];

      final response = await source.getAll();

      expect(client.lastCall.url, '/labels');
      expect(response.toSuccess().body, hasLength(1));
    });

    test('getAll url-encodes the search term', () async {
      client.nextBody = <dynamic>[];

      await source.getAll(query: 'needs review');

      expect(client.lastCall.url, '/labels?s=needs+review');
    });

    test('create PUTs the serialised label', () async {
      client.nextBody = labelJson(title: 'Bug');

      await source.create(LabelDto.fromJson(labelJson(title: 'Bug')));

      expect(client.lastCall.verb, 'PUT');
      expect(client.lastCall.url, '/labels');
      expect(client.lastCall.body['title'], 'Bug');
    });
  });

  group('TaskLabelDataSource', () {
    test('delete removes the label from the task', () async {
      client.nextBody = labelJson(id: 5);

      await TaskLabelDataSource(client).delete(
        LabelTaskDto(
          label: LabelDto.fromJson(labelJson(id: 5)),
          task: TaskDto.fromJson(taskJson(id: 100)),
        ),
      );

      expect(client.lastCall.verb, 'DELETE');
      expect(client.lastCall.url, '/tasks/100/labels/5');
    });
  });

  group('TaskLabelBulkDataSource', () {
    test('update POSTs the label set and unwraps the labels key', () async {
      client.nextBody = {
        'labels': [labelJson(id: 5), labelJson(id: 6)],
      };

      final response = await TaskLabelBulkDataSource(client).update(
        TaskDto.fromJson(taskJson(id: 100)),
        [LabelDto.fromJson(labelJson(id: 5))],
      );

      expect(client.lastCall.verb, 'POST');
      expect(client.lastCall.url, '/tasks/100/labels/bulk');
      expect(client.lastCall.body['labels'], hasLength(1));
      expect(response.toSuccess().body.map((l) => l.id), [5, 6]);
    });
  });

  group('TaskCommentDataSource', () {
    late TaskCommentDataSource source;
    setUp(() => source = TaskCommentDataSource(client));

    test('getAll GETs the task comments', () async {
      client.nextBody = [commentJson(id: 7), commentJson(id: 8)];

      final response = await source.getAll(100);

      expect(client.lastCall.verb, 'GET');
      expect(client.lastCall.url, '/tasks/100/comments');
      expect(response.toSuccess().body.map((c) => c.id), [7, 8]);
    });

    test('create PUTs a new comment', () async {
      client.nextBody = commentJson();

      await source.create(100, TaskCommentDto.fromJson(commentJson()));

      expect(client.lastCall.verb, 'PUT');
      expect(client.lastCall.url, '/tasks/100/comments');
      expect(client.lastCall.body['comment'], '<p>Nice</p>');
    });

    test('update POSTs to the comment id', () async {
      client.nextBody = commentJson(id: 7);

      await source.update(100, TaskCommentDto.fromJson(commentJson(id: 7)));

      expect(client.lastCall.verb, 'POST');
      expect(client.lastCall.url, '/tasks/100/comments/7');
    });

    test('delete DELETEs the comment id', () async {
      await source.delete(100, 7);

      expect(client.lastCall.verb, 'DELETE');
      expect(client.lastCall.url, '/tasks/100/comments/7');
    });
  });

  group('UserDataSource', () {
    late UserDataSource source;
    setUp(() => source = UserDataSource(client));

    test('getCurrentUser GETs /user', () async {
      client.nextBody = userJson(username: 'demo');

      final response = await source.getCurrentUser();

      expect(client.lastCall.verb, 'GET');
      expect(client.lastCall.url, '/user');
      expect(response.toSuccess().body.username, 'demo');
    });

    test(
      'setCurrentUserSettings POSTs the settings and echoes them back',
      () async {
        final settings = UserSettingsDto.fromJson(userSettingsJson());

        final response = await source.setCurrentUserSettings(settings);

        expect(client.lastCall.verb, 'POST');
        expect(client.lastCall.url, '/user/settings/general');
        expect(client.lastCall.body['default_project_id'], 3);
        expect(response.toSuccess().body, same(settings));
      },
    );
  });

  group('ServerDataSource', () {
    test('getInfo GETs /info', () async {
      client.nextBody = serverJson(version: 'v0.24.0');

      final response = await ServerDataSource(client).getInfo();

      expect(client.lastCall.verb, 'GET');
      expect(client.lastCall.url, '/info');
      expect(response.toSuccess().body.version, 'v0.24.0');
    });
  });
}
