import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/domain/entities/project.dart';

part 'project_controller.g.dart';

@riverpod
class ProjectController extends _$ProjectController {
  @override
  Future<List<Project>> build() async {
    return ref.read(projectRepositoryProvider).getAll();
  }

  void reload() async {
    state = AsyncData(await ref.read(projectRepositoryProvider).getAll());
  }

  void create(Project project) {
    ref.read(projectRepositoryProvider).create(project);
    reload();
  }
}
