/// Repositories are a thin seam: convert domain → DTO, call the data source,
/// convert the response back. These tests assert exactly that seam.
///
/// The HTTP contract is covered in `test/data/data_sources/`, the DTO field
/// mapping in `test/data/models/`, and the success/error/exception branches of
/// the response mapper in `test/core/utils/mapping_extensions_test.dart`.
library;

import 'package:background_downloader/background_downloader.dart'
    show DownloadTask, TaskStatus, TaskStatusUpdate;
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/network/response.dart';
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
import 'package:vikunja_app/data/data_sources/version_data_source.dart';
import 'package:vikunja_app/data/repositories/bucket_repository_impl.dart';
import 'package:vikunja_app/data/repositories/label_repository_impl.dart';
import 'package:vikunja_app/data/repositories/project_repository_impl.dart';
import 'package:vikunja_app/data/repositories/project_view_repository_impl.dart';
import 'package:vikunja_app/data/repositories/server_repository_impl.dart';
import 'package:vikunja_app/data/repositories/task_comment_repository_impl.dart';
import 'package:vikunja_app/data/repositories/task_label_bulk_repository_impl.dart';
import 'package:vikunja_app/data/repositories/task_label_repository_impl.dart';
import 'package:vikunja_app/data/repositories/task_repository_impl.dart';
import 'package:vikunja_app/data/repositories/user_repository_impl.dart';
import 'package:vikunja_app/data/repositories/version_repository_impl.dart';
import 'package:vikunja_app/domain/entities/task_label.dart';
import 'package:vikunja_app/domain/entities/version.dart';

import '../../helpers/builders.dart';
import '../../helpers/json_fixtures.dart';
import '../../helpers/recording_client.dart';

void main() {
  late RecordingClient client;

  setUp(() => client = RecordingClient());

  group('ProjectRepositoryImpl', () {
    late ProjectRepositoryImpl repository;
    setUp(() => repository = ProjectRepositoryImpl(ProjectDataSource(client)));

    test(
      'getAll returns domain projects and preserves pagination headers',
      () async {
        client.nextBody = [projectJson(id: 1), projectJson(id: 2)];

        final response = await repository.getAll(page: 2);

        expect(response.toSuccess().body.map((p) => p.id), [1, 2]);
        expect(response.toSuccess().headers['x-pagination-total-pages'], '1');
        expect(client.lastCall.queryParameters, {
          'page': ['2'],
        });
      },
    );

    test('getAll passes an error response straight through', () async {
      client.nextResponse = ErrorResponse<dynamic>(503, const {}, {
        'm': 'down',
      });

      final response = await repository.getAll();

      expect(response.isError, isTrue);
      expect(response.toError().statusCode, 503);
    });

    test(
      'create sends the domain project as a DTO and maps the result back',
      () async {
        client.nextBody = projectJson(id: 5);

        final response = await repository.create(buildProject(title: 'New'));

        expect(client.lastCall.body['title'], 'New');
        expect(response.toSuccess().body.id, 5);
      },
    );

    test('update sends the domain project as a DTO', () async {
      client.nextBody = projectJson(id: 5);

      await repository.update(buildProject(id: 5, title: 'Renamed'));

      expect(client.lastCall.url, '/projects/5');
      expect(client.lastCall.body['title'], 'Renamed');
    });
  });

  group('TaskRepositoryImpl', () {
    late TaskRepositoryImpl repository;
    setUp(() => repository = TaskRepositoryImpl(TaskDataSource(client)));

    test('add converts the task and maps the created task back', () async {
      client.nextBody = taskJson(id: 12, title: 'Added');

      final response = await repository.add(3, buildTask(title: 'Added'));

      expect(client.lastCall.body['title'], 'Added');
      expect(response.toSuccess().body.id, 12);
    });

    test('update converts the task and maps the saved task back', () async {
      client.nextBody = taskJson(id: 12);

      final response = await repository.update(buildTask(id: 12));

      expect(client.lastCall.url, '/tasks/12');
      expect(response.toSuccess().body.id, 12);
    });

    test('getTask maps a single task', () async {
      client.nextBody = taskJson(id: 4, title: 'One');

      expect((await repository.getTask(4)).toSuccess().body.title, 'One');
    });

    test('delete forwards without conversion', () async {
      final response = await repository.delete(4);

      expect(client.lastCall.verb, 'DELETE');
      expect(response.isSuccessful, isTrue);
    });

    test('getAllByProject maps a task list', () async {
      client.nextBody = [taskJson(id: 1), taskJson(id: 2)];

      final response = await repository.getAllByProject(3);

      expect(response.toSuccess().body.map((t) => t.id), [1, 2]);
    });

    test('getAllByProjectView maps a task list', () async {
      client.nextBody = [taskJson(id: 1)];

      final response = await repository.getAllByProjectView(3, 11);

      expect(response.toSuccess().body.single.id, 1);
    });

    test('getByFilterString maps a task list', () async {
      client.nextBody = [taskJson(id: 1)];

      final response = await repository.getByFilterString('done = false');

      expect(response.toSuccess().body.single.id, 1);
    });

    test(
      'downloadAttachment converts the attachment before delegating',
      () async {
        // The real FileDownloader needs a platform channel, so the data source is
        // stubbed; what matters here is that the domain object was converted.
        final stub = _RecordingTaskDataSource(client);

        final update = await TaskRepositoryImpl(
          stub,
        ).downloadAttachment(100, buildAttachment(fileName: 'notes.txt'));

        expect(stub.downloadedTaskId, 100);
        expect(stub.downloadedFileName, 'notes.txt');
        expect(update.status, TaskStatus.complete);
      },
    );
  });

  group('BucketRepositoryImpl', () {
    late BucketRepositoryImpl repository;
    setUp(() => repository = BucketRepositoryImpl(BucketDataSource(client)));

    test('add converts the bucket and maps the created bucket back', () async {
      client.nextBody = bucketJson(id: 50, title: 'Doing');

      final response = await repository.add(3, 11, buildBucket(title: 'Doing'));

      expect(client.lastCall.body['title'], 'Doing');
      expect(response.toSuccess().body.id, 50);
    });

    test('update converts the bucket', () async {
      client.nextBody = bucketJson(id: 50);

      await repository.update(3, 11, buildBucket(id: 50, title: 'Renamed'));

      expect(client.lastCall.url, '/projects/3/views/11/buckets/50');
      expect(client.lastCall.body['title'], 'Renamed');
    });

    test('getAllByList maps buckets and their nested tasks', () async {
      client.nextBody = [
        bucketJson(id: 50, tasks: [taskJson(id: 1)]),
      ];

      final response = await repository.getAllByList(3, 11);

      expect(response.toSuccess().body.single.tasks.single.id, 1);
    });

    test(
      'delete, updateTaskBucket and updateTaskPosition forward unchanged',
      () async {
        expect((await repository.delete(3, 11, 50)).isSuccessful, isTrue);
        expect(
          (await repository.updateTaskBucket(7, 51, 3, 11)).isSuccessful,
          isTrue,
        );
        expect(
          (await repository.updateTaskPosition(7, 11, 1.0)).isSuccessful,
          isTrue,
        );
      },
    );
  });

  group('ProjectViewRepositoryImpl', () {
    test('update converts the view and maps the result back', () async {
      client.nextBody = projectViewJson(id: 11, projectId: 3);

      final response = await ProjectViewRepositoryImpl(
        ProjectViewDataSource(client),
      ).update(buildView(id: 11, projectId: 3));

      expect(client.lastCall.url, '/projects/3/views/11');
      expect(response.toSuccess().body.id, 11);
    });
  });

  group('LabelRepositoryImpl', () {
    late LabelRepositoryImpl repository;
    setUp(() => repository = LabelRepositoryImpl(LabelDataSource(client)));

    test('getAll maps a label list and forwards the query', () async {
      client.nextBody = [labelJson(id: 5, title: 'Bug')];

      final response = await repository.getAll(query: 'bug');

      expect(client.lastCall.url, '/labels?s=bug');
      expect(response.toSuccess().body.single.title, 'Bug');
    });

    test('create converts the label and maps the result back', () async {
      client.nextBody = labelJson(id: 6, title: 'Feature');

      final response = await repository.create(buildLabel(title: 'Feature'));

      expect(client.lastCall.body['title'], 'Feature');
      expect(response.toSuccess().body.id, 6);
    });
  });

  group('TaskLabelRepositoryImpl', () {
    test('delete converts the label/task pair', () async {
      client.nextBody = labelJson(id: 5);

      final response = await TaskLabelRepositoryImpl(
        TaskLabelDataSource(client),
      ).delete(LabelTask(label: buildLabel(id: 5), task: buildTask(id: 100)));

      expect(client.lastCall.url, '/tasks/100/labels/5');
      expect(response.toSuccess().body.id, 5);
    });
  });

  group('TaskLabelBulkRepositoryImpl', () {
    test(
      'update converts the whole label set and maps the result back',
      () async {
        client.nextBody = {
          'labels': [labelJson(id: 5), labelJson(id: 6)],
        };

        final response = await TaskLabelBulkRepositoryImpl(
          TaskLabelBulkDataSource(client),
        ).update(buildTask(id: 100), [buildLabel(id: 5), buildLabel(id: 6)]);

        expect(client.lastCall.body['labels'], hasLength(2));
        expect(response.toSuccess().body.map((l) => l.id), [5, 6]);
      },
    );
  });

  group('TaskCommentRepositoryImpl', () {
    late TaskCommentRepositoryImpl repository;
    setUp(
      () =>
          repository = TaskCommentRepositoryImpl(TaskCommentDataSource(client)),
    );

    Map<String, dynamic> commentJson({int id = 7, String text = '<p>Hi</p>'}) =>
        {
          'id': id,
          'comment': text,
          'author': userJson(),
          'created': isoDate,
          'updated': isoDate,
        };

    test('getAll maps a comment list', () async {
      client.nextBody = [commentJson(id: 7), commentJson(id: 8)];

      final response = await repository.getAll(100);

      expect(response.toSuccess().body.map((c) => c.id), [7, 8]);
    });

    test('create converts the comment and maps the result back', () async {
      client.nextBody = commentJson(id: 9, text: '<p>New</p>');

      final response = await repository.create(
        100,
        buildComment(comment: '<p>New</p>'),
      );

      expect(client.lastCall.body['comment'], '<p>New</p>');
      expect(response.toSuccess().body.id, 9);
    });

    test('update converts the comment', () async {
      client.nextBody = commentJson(id: 7);

      await repository.update(100, buildComment(id: 7, comment: '<p>Edit</p>'));

      expect(client.lastCall.url, '/tasks/100/comments/7');
      expect(client.lastCall.body['comment'], '<p>Edit</p>');
    });

    test('delete forwards without conversion', () async {
      expect((await repository.delete(100, 7)).isSuccessful, isTrue);
      expect(client.lastCall.verb, 'DELETE');
    });
  });

  group('UserRepositoryImpl', () {
    late UserRepositoryImpl repository;
    setUp(() => repository = UserRepositoryImpl(UserDataSource(client)));

    test('getCurrentUser maps the user', () async {
      client.nextBody = userJson(username: 'demo');

      expect(
        (await repository.getCurrentUser()).toSuccess().body.username,
        'demo',
      );
    });

    test('setCurrentUserSettings converts the settings both ways', () async {
      final response = await repository.setCurrentUserSettings(
        buildUserSettings(defaultProjectId: 4, language: 'de'),
      );

      expect(client.lastCall.body['default_project_id'], 4);
      expect(response.toSuccess().body.language, 'de');
    });
  });

  group('ServerRepositoryImpl', () {
    test('getInfo maps the server info', () async {
      client.nextBody = serverJson(version: 'v0.24.0');

      final response = await ServerRepositoryImpl(
        ServerDataSource(client),
      ).getInfo();

      expect(response.toSuccess().body.version, 'v0.24.0');
    });
  });

  group('VersionRepositoryImpl', () {
    test('parses the latest tag into a Version', () async {
      final repository = VersionRepositoryImpl(
        _StubVersionDataSource(latest: '0.2.0', current: '0.1.8+42'),
      );

      expect(await repository.getLatestVersionTag(), Version(0, 2, 0));
    });

    test('returns null when there is no latest tag', () async {
      final repository = VersionRepositoryImpl(
        _StubVersionDataSource(latest: null, current: '0.1.8'),
      );

      expect(await repository.getLatestVersionTag(), isNull);
    });

    test('returns null when the latest tag is not semver', () async {
      final repository = VersionRepositoryImpl(
        _StubVersionDataSource(latest: 'nightly', current: '0.1.8'),
      );

      expect(await repository.getLatestVersionTag(), isNull);
    });

    test('parses the current tag including its build metadata', () async {
      final repository = VersionRepositoryImpl(
        _StubVersionDataSource(latest: null, current: '0.1.8+42'),
      );

      expect(
        await repository.getCurrentVersionTag(),
        Version(0, 1, 8, null, '42'),
      );
    });
  });
}

class _StubVersionDataSource implements VersionDataSource {
  _StubVersionDataSource({required this.latest, required this.current});

  final String? latest;
  final String current;

  @override
  Future<String?> getLatestVersionTag() async => latest;

  @override
  Future<String> getCurrentVersionTag() async => current;
}

/// Bypasses the real `FileDownloader`, which needs a platform channel.
class _RecordingTaskDataSource extends TaskDataSource {
  _RecordingTaskDataSource(super.client);

  int? downloadedTaskId;
  String? downloadedFileName;

  @override
  Future<TaskStatusUpdate> downloadAttachment(int taskId, attachment) async {
    downloadedTaskId = taskId;
    downloadedFileName = attachment.file.name;
    return TaskStatusUpdate(
      DownloadTask(url: 'https://example.com', filename: attachment.file.name),
      TaskStatus.complete,
    );
  }
}
