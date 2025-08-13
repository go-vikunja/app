import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/data_source_provider.dart';
import 'package:vikunja_app/data/repositories/project_repository_impl.dart';
import 'package:vikunja_app/data/repositories/settings_repository_impl.dart';
import 'package:vikunja_app/data/repositories/user_repository_impl.dart';
import 'package:vikunja_app/data/repositories/version_repository_impl.dart';
import 'package:vikunja_app/domain/repositories/project_repository.dart';
import 'package:vikunja_app/domain/repositories/settings_repository.dart';
import 'package:vikunja_app/domain/repositories/user_repository.dart';
import 'package:vikunja_app/domain/repositories/version_repository.dart';

part 'reppository_provider.g.dart';

@riverpod
ProjectRepository projectRepository(Ref ref) {
  var projectDataSource = ref.watch(projectDataSourceProvider);
  return ProjectRepositoryImpl(projectDataSource);
}

@riverpod
SettingsRepository settingsRepository(Ref ref) {
  var settingsDataSource = ref.watch(settingsDataSourceProvider);
  return SettingsRepositoryImpl(settingsDataSource);
}

@riverpod
UserRepository userRepository(Ref ref) {
  var userDataSource = ref.watch(userDataSourceProvider);
  return UserRepositoryImpl(userDataSource);
}

@riverpod
VersionRepository versionRepository(Ref ref) {
  var versionDataSource = ref.watch(versionDataSourceProvider);
  return VersionRepositoryImpl(versionDataSource);
}
