import 'package:vikunja_app/domain/entities/project.dart';

class ProjectListModel {
  List<Project> projects;
  bool isLoadingNextPage;

  ProjectListModel(this.projects, {this.isLoadingNextPage = false});

  ProjectListModel copyWith({
    List<Project>? projects,
    bool? isLoadingNextPage,
  }) {
    return ProjectListModel(
      projects ?? this.projects,
      isLoadingNextPage: isLoadingNextPage ?? this.isLoadingNextPage,
    );
  }
}
