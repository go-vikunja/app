import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/project_list_model.dart';
import 'package:vikunja_app/presentation/manager/pagination_mixin.dart';

part 'projects_controller.g.dart';

@riverpod
class ProjectsController extends _$ProjectsController with PaginationMixin<Project> {

  @override
  Future<ProjectListModel> build() async {
    resetPagination();

    var response = await ref.read(projectRepositoryProvider).getAll(page: 1);
    
    if (response.isSuccessful) {
      updateTotalPages(response.toSuccess().headers);
      return ProjectListModel(response.toSuccess().body);
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
      state = AsyncData(ProjectListModel(response.toSuccess().body));
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
    if (!canLoadNextPage) return;

    final currentModel = state.value;
    if (currentModel == null) return;

    state = AsyncData(currentModel.copyWith(isLoadingNextPage: true));

    await loadMoreItems(
      fetcher: (page) => ref.read(projectRepositoryProvider).getAll(page: page),
      stateUpdater: (newProjects) {
        final latestModel = state.value;
        if (latestModel != null) {
          state = AsyncData(latestModel.copyWith(
            projects: [...latestModel.projects, ...newProjects as List<Project>],
            isLoadingNextPage: false,
          ));
        }
      },
    );

    // Fallback
    if (state.value?.isLoadingNextPage == true) {
      state = AsyncData(state.value!.copyWith(isLoadingNextPage: false));
    }
  }

  void create(Project project) async {
    await ref.read(projectRepositoryProvider).create(project);
    reload();
  }
}
