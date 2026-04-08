import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/presentation/manager/pagination_mixin.dart';

part 'projects_controller.g.dart';

@riverpod
class ProjectsController extends _$ProjectsController with PaginationMixin<Project> {

  @override
  Future<List<Project>> build() async {
    resetPagination();

    var response = await ref.read(projectRepositoryProvider).getAll(page: 1);
    
    if (response.isSuccessful) {
      updateTotalPages(response.toSuccess().headers);
      return response.toSuccess().body;
    } else if (response.isException) {
      throw Exception(response.toException().message);
    } else {
      throw Exception(response.toError().error);
    }
  }

  void reload() async {
    state = const AsyncLoading();
    resetPagination();
    
    var response = await ref.read(projectRepositoryProvider).getAll(page: 1);
    if (response.isSuccessful) {
      updateTotalPages(response.toSuccess().headers);
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

  Future<void> loadNextPage() async {
    if (state.isLoading || state.hasError) return;
    
    await loadMoreItems(
      fetcher: (page) => ref.read(projectRepositoryProvider).getAll(page: page),
      stateUpdater: (newProjects) {
        final currentProjects = state.value ?? [];
        state = AsyncData([...currentProjects, ...newProjects as List<Project>]);
      },
    );
  }

  void create(Project project) async {
    await ref.read(projectRepositoryProvider).create(project);
    reload();
  }
}
