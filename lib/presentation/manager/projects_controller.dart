import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/project_list_model.dart';
import 'package:vikunja_app/presentation/manager/pagination_mixin.dart';

part 'projects_controller.g.dart';

@riverpod
class ProjectsController extends _$ProjectsController
    with PaginationMixin<Project> {
  String get _currentSearchQuery => state.value?.searchQuery ?? '';

  bool _isCurrentSearch(String searchQuery) {
    final current = state.value;
    return current != null &&
        current.searchQuery == searchQuery &&
        !current.isSearching;
  }

  @override
  Future<ProjectListModel> build() async {
    resetPagination();

    var response = await loadProjects();

    if (response.isSuccessful) {
      updateTotalPages(response.toSuccess().headers);
      return ProjectListModel(
        response.toSuccess().body,
        searchQuery: _currentSearchQuery,
      );
    } else if (response.isException) {
      throw Exception(response.toException().message);
    } else {
      throw Exception(response.toError().error);
    }
  }

  void reload() async {
    final searchQuery = _currentSearchQuery;
    state = const AsyncLoading();
    resetPagination();

    var response = await loadProjects(searchQuery: searchQuery);
    if (response.isSuccessful) {
      updateTotalPages(response.toSuccess().headers);
      state = AsyncData(
        ProjectListModel(response.toSuccess().body, searchQuery: searchQuery),
      );
    } else if (response.isException) {
      state = AsyncError(
        response.toException().message,
        response.toException().stackTrace,
      );
    } else {
      state = AsyncError(response.toError().error, StackTrace.empty);
    }
  }

  Future<void> setSearchQuery(String query) async {
    final trimmed = query.trim();
    final current = state.value;
    if (current == null || trimmed == current.searchQuery) {
      return;
    }

    state = AsyncData(
      current.copyWith(searchQuery: trimmed, isSearching: true),
    );

    resetPagination();
    var response = await loadProjects(searchQuery: trimmed);
    if (state.value?.searchQuery != trimmed) {
      return;
    }

    if (response.isSuccessful) {
      updateTotalPages(response.toSuccess().headers);
      state = AsyncData(
        ProjectListModel(response.toSuccess().body, searchQuery: trimmed),
      );
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
    if (currentModel == null || currentModel.isSearching) return;

    final requestedSearchQuery = currentModel.searchQuery;
    state = AsyncData(currentModel.copyWith(isLoadingNextPage: true));

    await loadMoreItems(
      fetcher: (page) => ref
          .read(projectRepositoryProvider)
          .getAll(
            page: page,
            search: requestedSearchQuery.isEmpty ? null : requestedSearchQuery,
          ),
      shouldApply: () => _isCurrentSearch(requestedSearchQuery),
      stateUpdater: (newProjects) {
        final latestModel = state.value;
        if (latestModel != null && _isCurrentSearch(requestedSearchQuery)) {
          state = AsyncData(
            latestModel.copyWith(
              projects: [
                ...latestModel.projects,
                ...newProjects as List<Project>,
              ],
              isLoadingNextPage: false,
            ),
          );
        }
      },
    );

    final latest = state.value;
    if (latest?.isLoadingNextPage == true &&
        latest?.searchQuery == requestedSearchQuery) {
      state = AsyncData(latest!.copyWith(isLoadingNextPage: false));
    }
  }

  void create(Project project) async {
    await ref.read(projectRepositoryProvider).create(project);
    reload();
  }

  Future<Response<List<Project>>> loadProjects({String? searchQuery}) async {
    final query = searchQuery ?? _currentSearchQuery;
    var response = await ref
        .read(projectRepositoryProvider)
        .getAll(page: 1, search: query.isEmpty ? null : query);

    if (response.isSuccessful) {
      var successResponse = (response as SuccessResponse<List<Project>>);
      if (query.isNotEmpty) {
        return SuccessResponse(
          successResponse.body,
          successResponse.statusCode,
          successResponse.headers,
        );
      }

      return SuccessResponse(
        _asTopLevelTree(successResponse.body, successResponse.body),
        successResponse.statusCode,
        successResponse.headers,
      );
    }

    return response;
  }

  List<Project> _asTopLevelTree(
    List<Project> candidates,
    List<Project> allProjects,
  ) {
    final topLevelProjects = candidates
        .where((e) => e.parentProjectId == 0)
        .toList();
    for (var topLevelProject in topLevelProjects) {
      _findSubproject(topLevelProject, allProjects);
    }
    return topLevelProjects;
  }

  void _findSubproject(Project project, List<Project> projects) {
    project.subprojects = projects
        .where((e) => e.parentProjectId == project.id)
        .toList();
    for (var e in project.subprojects) {
      _findSubproject(e, projects);
    }
  }
}
