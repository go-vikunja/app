import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/data/data_sources/project_data_source.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_data_source.dart';
import 'package:vikunja_app/data/data_sources/user_data_source.dart';
import 'package:vikunja_app/data/data_sources/version_data_source.dart';

part 'data_source_provider.g.dart';

@riverpod
ProjectDataSource projectDataSource(Ref ref) {
  final client = ref.watch(clientProviderProvider);
  return ProjectDataSource(client, FlutterSecureStorage());
}

@riverpod
TaskDataSource taskDataSource(Ref ref) {
  final client = ref.watch(clientProviderProvider);
  return TaskDataSource(client);
}

@riverpod
UserDataSource userDataSource(Ref ref) {
  final client = ref.watch(clientProviderProvider);
  return UserDataSource(client);
}

@riverpod
SettingsDatasource settingsDataSource(Ref ref) {
  return SettingsDatasource(FlutterSecureStorage());
}

@riverpod
VersionDataSource versionDataSource(Ref ref) {
  return VersionDataSource();
}
