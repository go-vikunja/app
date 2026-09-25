import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/core/di/data_source_provider.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/data/data_sources/project_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_data_source.dart';
import 'package:vikunja_app/data/local/offline_database.dart';
import 'package:vikunja_app/data/models/project_dto.dart';
import 'package:vikunja_app/data/models/task_dto.dart';

class OfflineStatus {
  final bool isOffline;
  final int pendingCount;
  final bool isFlushing;
  final String? flushError;

  const OfflineStatus({
    this.isOffline = false,
    this.pendingCount = 0,
    this.isFlushing = false,
    this.flushError,
  });

  bool get showFlush => !isOffline && pendingCount > 0 && !isFlushing;

  OfflineStatus copyWith({
    bool? isOffline,
    int? pendingCount,
    bool? isFlushing,
    String? flushError,
    bool clearError = false,
  }) {
    return OfflineStatus(
      isOffline: isOffline ?? this.isOffline,
      pendingCount: pendingCount ?? this.pendingCount,
      isFlushing: isFlushing ?? this.isFlushing,
      flushError: clearError ? null : (flushError ?? this.flushError),
    );
  }
}

final offlineDatabaseProvider = Provider<OfflineDatabase>((ref) {
  final database = OfflineDatabase();
  ref.onDispose(database.close);
  return database;
});

final offlineControllerProvider =
    NotifierProvider<OfflineController, OfflineStatus>(OfflineController.new);

final offlineIsOfflineProvider = Provider<bool>((ref) {
  return ref.watch(offlineControllerProvider).isOffline;
});

final hasOfflineCacheProvider = FutureProvider<bool>((ref) {
  return ref.watch(offlineDatabaseProvider).hasSnapshot();
});

class OfflineController extends Notifier<OfflineStatus> {
  OfflineDatabase get _db => ref.read(offlineDatabaseProvider);

  @override
  OfflineStatus build() {
    Future.microtask(refreshPendingCount);
    return const OfflineStatus();
  }

  Future<void> refreshPendingCount() async {
    final count = await _db.pendingCount();
    state = state.copyWith(pendingCount: count);
  }

  Future<void> enterOffline() async {
    await refreshPendingCount();
    state = state.copyWith(isOffline: true, clearError: true);
  }

  Future<bool> tryGoOnline() async {
    final info = await ref.read(serverDataSourceProvider).getInfo();
    if (!info.isSuccessful) return false;
    state = state.copyWith(isOffline: false, clearError: true);
    await refreshPendingCount();
    return true;
  }

  Future<bool> flush() async {
    if (state.isOffline || state.isFlushing) return false;
    state = state.copyWith(isFlushing: true, clearError: true);

    final taskSource = ref.read(taskDataSourceProvider);
    final projectSource = ref.read(projectDataSourceProvider);

    try {
      final mutations = await _db.pending();
      for (final mutation in mutations) {
        final error = await _apply(mutation, taskSource, projectSource);
        if (error != null) {
          state = state.copyWith(
            isFlushing: false,
            flushError: error,
            pendingCount: await _db.pendingCount(),
          );
          return false;
        }
        await _db.deleteMutation(mutation.id);
      }
      state = state.copyWith(
        isFlushing: false,
        pendingCount: 0,
        clearError: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isFlushing: false,
        flushError: e.toString(),
        pendingCount: await _db.pendingCount(),
      );
      return false;
    }
  }

  Future<String?> _apply(
    OfflineMutation mutation,
    TaskDataSource tasks,
    ProjectDataSource projects,
  ) async {
    switch (mutation.op) {
      case 'project.create':
        final response = await projects.create(
          ProjectDto.fromJson(
            mutation.payload['project'] as Map<String, dynamic>,
          ),
        );
        if (!response.isSuccessful) return _errorMessage(response);
        final localId = mutation.payload['localId'] as int;
        await _db.remapId(
          kind: 'project',
          from: localId,
          to: response.toSuccess().body.id,
        );
      case 'project.update':
        final response = await projects.update(
          ProjectDto.fromJson(
            mutation.payload['project'] as Map<String, dynamic>,
          ),
        );
        if (!response.isSuccessful) return _errorMessage(response);
      case 'task.create':
        final taskJson = mutation.payload['task'] as Map<String, dynamic>;
        final response = await tasks.add(
          mutation.payload['projectId'] as int,
          TaskDto.fromJson(taskJson),
        );
        if (!response.isSuccessful) return _errorMessage(response);
        await _db.remapId(
          kind: 'task',
          from: taskJson['id'] as int,
          to: response.toSuccess().body.id,
        );
      case 'task.update':
        final response = await tasks.update(
          TaskDto.fromJson(mutation.payload['task'] as Map<String, dynamic>),
        );
        if (!response.isSuccessful) return _errorMessage(response);
      case 'task.delete':
        final response = await tasks.delete(mutation.payload['id'] as int);
        if (!response.isSuccessful) return _errorMessage(response);
      default:
        return 'Unknown mutation ${mutation.op}';
    }
    return null;
  }

  String _errorMessage(Response<dynamic> response) {
    if (response.isError) {
      return response.toError().error['message']?.toString() ??
          'Error ${response.toError().statusCode}';
    }
    if (response.isException) {
      return response.toException().message;
    }
    return 'Flush failed';
  }
}

SuccessResponse<T> offlineSuccess<T>(T body) =>
    SuccessResponse<T>(body, 200, {});
