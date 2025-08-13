import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/reppository_provider.dart';
import 'package:vikunja_app/domain/entities/project.dart';

part 'project_controller.g.dart';

@riverpod
class ProjectController extends _$ProjectController {
  @override
  Future<List<Project>> build() async {
    return ref.read(projectRepositoryProvider).getAll();
  }
}
