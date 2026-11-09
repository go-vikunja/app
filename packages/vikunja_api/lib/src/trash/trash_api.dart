import 'package:dio/dio.dart';
import 'package:vikunja_api/src/dto/project_codec.dart';
import 'package:vikunja_api/src/dto/task_codec.dart';
import 'package:vikunja_api/src/dto/trash_codec.dart';
import 'package:vikunja_api/src/transport/all_pages.dart';
import 'package:vikunja_api/src/trash/trash_port.dart';
import 'package:vikunja_api/src/write/write_transport.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

const _notInTrash = 4042;
const _projectNotFound = 3001;

final class TrashApi implements TrashPort {
  new({required Dio dio, required ServerConnection connection})
    : _transport = WriteTransport(dio, connection),
      _perPage = connection.info.maxItemsPerPage,
      _available =
          connection.capabilities.has(Capability.trash) &&
          connection.preferredApiVersion == ApiVersion.v2;

  final WriteTransport _transport;
  final int _perPage;
  final bool _available;

  @override
  Future<List<TrashedTask>> tasks() async {
    _requireTrash();
    return await readAllPages(
      _transport,
      '/tasks/deleted',
      parseTrashedTask,
      idOf: (trashed) => trashed.task.id,
      perPage: _perPage,
    );
  }

  @override
  Future<List<TrashedProject>> projects() async {
    _requireTrash();
    return await readAllPages(
      _transport,
      '/projects/deleted',
      parseTrashedProject,
      idOf: (trashed) => trashed.project.id,
      perPage: _perPage,
    );
  }

  @override
  Future<TrashCount> taskCount() => _count('/tasks/deleted/count');

  @override
  Future<TrashCount> projectCount() => _count('/projects/deleted/count');

  Future<TrashCount> _count(String path) async {
    _requireTrash();
    return _transport.decode<TrashCount>(
      await _transport.send('GET', path),
      parseTrashCount,
    );
  }

  @override
  Future<void> emptyTasks({bool includeOthers = true}) =>
      _empty('/tasks/deleted', includeOthers: includeOthers);

  @override
  Future<void> emptyProjects({bool includeOthers = true}) =>
      _empty('/projects/deleted', includeOthers: includeOthers);

  Future<void> _empty(String path, {required bool includeOthers}) async {
    _requireTrash();
    await _transport.send(
      'DELETE',
      path,
      query: {'include_others': '$includeOthers'},
    );
  }

  @override
  Future<Task> restoreTask(int id) async {
    _requireTrash();
    try {
      return _transport.decode<Task>(
        await _transport.send('POST', '/tasks/$id/restore'),
        parseTask,
      );
    } on DomainError catch (error) {
      if (error.code != _notInTrash) rethrow;
    }
    return _transport.decode<Task>(
      await _transport.send('GET', '/tasks/$id'),
      parseTask,
    );
  }

  @override
  Future<Project> restoreProject(int id) async {
    _requireTrash();
    try {
      return _transport.decode<Project>(
        await _transport.send('POST', '/projects/$id/restore'),
        parseProject,
      );
    } on NotFound catch (error, stack) {
      if (error.code != _projectNotFound) rethrow;
      // The server has no "not in the trash" code for projects: a live one
      // answers 3001 as well.
      try {
        return _transport.decode<Project>(
          await _transport.send('GET', '/projects/$id'),
          parseProject,
        );
      } on VikunjaFailure {
        Error.throwWithStackTrace(error, stack);
      }
    }
  }

  @override
  Future<void> deleteTaskForever(int id) async {
    _requireTrash();
    await _transport.send('DELETE', '/tasks/$id/permanent');
  }

  @override
  Future<void> deleteProjectForever(int id) async {
    _requireTrash();
    await _transport.send('DELETE', '/projects/$id/permanent');
  }

  void _requireTrash() {
    if (!_available) throw const NotFound();
  }
}
