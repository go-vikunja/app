import 'package:vikunja_app/domain/entities/project.dart';

class ProjectListModel {
  List<Project> projects;
  bool isLoadingNextPage;
  String searchQuery;
  bool isSearching;

  ProjectListModel(
    this.projects, {
    this.isLoadingNextPage = false,
    this.searchQuery = '',
    this.isSearching = false,
  });

  ProjectListModel copyWith({
    List<Project>? projects,
    bool? isLoadingNextPage,
    String? searchQuery,
    bool? isSearching,
  }) {
    return ProjectListModel(
      projects ?? this.projects,
      isLoadingNextPage: isLoadingNextPage ?? this.isLoadingNextPage,
      searchQuery: searchQuery ?? this.searchQuery,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}
