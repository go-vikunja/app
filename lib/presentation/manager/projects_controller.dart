import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/domain/entities/project.dart';

part 'projects_controller.g.dart';

@riverpod
class ProjectsController extends _$ProjectsController {
  @override
  Future<List<Project>> build() async {
    return ref.read(projectRepositoryProvider).getAll();
  }

  void reload() async {
    state = AsyncData(await ref.read(projectRepositoryProvider).getAll());
  }

  void create(Project project) async {
    await ref.read(projectRepositoryProvider).create(project);
    reload();
  }
}
