import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/data_source_provider.dart';
import 'package:vikunja_app/data/repositories/bucket_repository_impl.dart';
import 'package:vikunja_app/data/repositories/label_repository_impl.dart';
import 'package:vikunja_app/data/repositories/project_repository_impl.dart';
import 'package:vikunja_app/data/repositories/project_view_repository_impl.dart';
import 'package:vikunja_app/data/repositories/server_repository_impl.dart';
import 'package:vikunja_app/data/repositories/settings_repository_impl.dart';
import 'package:vikunja_app/data/repositories/task_label_bulk_repository_impl.dart';
import 'package:vikunja_app/data/repositories/task_label_repository_impl.dart';
import 'package:vikunja_app/data/repositories/task_repository_impl.dart';
import 'package:vikunja_app/data/repositories/user_repository_impl.dart';
import 'package:vikunja_app/data/repositories/version_repository_impl.dart';
import 'package:vikunja_app/domain/repositories/bucket_repository.dart';
import 'package:vikunja_app/domain/repositories/project_repository.dart';
import 'package:vikunja_app/domain/repositories/project_view_repository.dart';
import 'package:vikunja_app/domain/repositories/server_repository.dart';
import 'package:vikunja_app/domain/repositories/settings_repository.dart';
import 'package:vikunja_app/domain/repositories/task_label_bulk_repository.dart';
import 'package:vikunja_app/domain/repositories/task_repository.dart';
import 'package:vikunja_app/domain/repositories/user_repository.dart';
import 'package:vikunja_app/domain/repositories/version_repository.dart';

part 'repository_provider.g.dart';

@riverpod
ProjectRepository projectRepository(Ref ref) {
  var projectDataSource = ref.watch(projectDataSourceProvider);
  return ProjectRepositoryImpl(projectDataSource);
}

@riverpod
ProjectViewRepository projectViewRepository(Ref ref) {
  var projectViewDataSource = ref.watch(projectViewDataSourceProvider);
  return ProjectViewRepositoryImpl(projectViewDataSource);
}

@riverpod
BucketRepository bucketRepository(Ref ref) {
  var bucketDataSource = ref.watch(bucketDataSourceProvider);
  return BucketRepositoryImpl(bucketDataSource);
}

@riverpod
TaskRepository taskRepository(Ref ref) {
  var taskDataSource = ref.watch(taskDataSourceProvider);
  return TaskRepositoryImpl(taskDataSource);
}

@riverpod
TaskLabelRepositoryImpl taskLabelRepository(Ref ref) {
  var taskLabelDataSource = ref.watch(taskLabelDataSourceProvider);
  return TaskLabelRepositoryImpl(taskLabelDataSource);
}

@riverpod
TaskLabelBulkRepository taskLabelBulkRepository(Ref ref) {
  var taskLabelBulkDataSource = ref.watch(taskLabelBulkDataSourceProvider);
  return TaskLabelBulkRepositoryImpl(taskLabelBulkDataSource);
}

@riverpod
LabelRepositoryImpl labelRepository(Ref ref) {
  var labelDataSource = ref.watch(labelDataSourceProvider);
  return LabelRepositoryImpl(labelDataSource);
}

@riverpod
UserRepository userRepository(Ref ref) {
  var userDataSource = ref.watch(userDataSourceProvider);
  return UserRepositoryImpl(userDataSource);
}

@riverpod
ServerRepository serverRepository(Ref ref) {
  var serverDataSource = ref.watch(serverDataSourceProvider);
  return ServerRepositoryImpl(serverDataSource);
}

@riverpod
SettingsRepository settingsRepository(Ref ref) {
  var settingsDataSource = ref.watch(settingsDataSourceProvider);
  return SettingsRepositoryImpl(settingsDataSource);
}

@riverpod
VersionRepository versionRepository(Ref ref) {
  var versionDataSource = ref.watch(versionDataSourceProvider);
  return VersionRepositoryImpl(versionDataSource);
}
