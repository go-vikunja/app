import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/domain/entities/project.dart';

part 'projects_controller.g.dart';

@riverpod
class ProjectsController extends _$ProjectsController {
  @override
  Future<List<Project>> build() async {
    var response = await ref.read(projectRepositoryProvider).getAll();
    if (response.isSuccessful) {
      return response.toSuccess().body;
    } else if (response.isException) {
      throw Exception(response.toException().message);
    } else {
      throw Exception(response.toError().error);
    }
  }

  void reload() async {
    var response = await ref.read(projectRepositoryProvider).getAll();
    if (response.isSuccessful) {
      state = AsyncData(response.toSuccess().body);
    } else if (response.isException) {
      state = AsyncError(
        response.toException().message,
        response.toException().stackTrace,
      );
    } else {
      state = AsyncError(response.toError().error, StackTrace.empty);
    }
  }

  void create(Project project) async {
    await ref.read(projectRepositoryProvider).create(project);
    reload();
  }
}
