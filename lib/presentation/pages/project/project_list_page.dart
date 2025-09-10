import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/presentation/manager/projects_controller.dart';
import 'package:vikunja_app/presentation/pages/project/expansion_title.dart';
import 'package:vikunja_app/presentation/pages/project/project_detail_page.dart';
import 'package:vikunja_app/presentation/widgets/project/add_project_dialog.dart';

class ProjectListPage extends ConsumerWidget {
  const ProjectListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(projectsControllerProvider);

    return controller.when(
      data: (projects) {
        return Scaffold(
          body: RefreshIndicator(
            child: ListView(
              padding: EdgeInsets.zero,
              children: ListTile.divideTiles(
                  context: context,
                  tiles: projects.map<Widget>((e) {
                    return _buildListItem(ref, e);
                  })).toList(),
            ),
            onRefresh: () async {
              ref.watch(projectsControllerProvider.notifier).reload();
            },
          ),
          appBar: AppBar(
            title: Text("Projects"),
            actions: [
              IconButton(
                icon: Icon(Icons.add),
                onPressed: () => _addProjectDialog(ref),
              )
            ],
          ),
        );
      },
      error: (err, _) => Center(child: Text('Error: $err')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildListItem(WidgetRef ref, Project project) {
    if (project.subprojects.isEmpty == true) {
      return ListTile(
        leading: Icon(Icons.list),
        title: Text(project.title),
        onTap: () {
          _navigateToProject(ref, project);
        },
      );
    } else {
      return VikunjaExpansionTile(
        title: Text(project.title),
        children:
            project.subprojects.map((e) => _buildListItem(ref, e)).toList(),
        onTitleTap: () {
          _navigateToProject(ref, project);
        },
      );
    }
  }

  void _addProjectDialog(WidgetRef ref) {
    showDialog(
      context: ref.context,
      builder: (_) => AddProjectDialog(
        onAdd: (name) => _addProject(name, ref),
      ),
    );
  }

  Future<void> _addProject(String name, WidgetRef ref) async {
    //TODO replace with injection
    final currentUser = await ref.read(userRepositoryProvider).getCurrentUser();

    ref
        .read(projectsControllerProvider.notifier)
        .create(Project(title: name, owner: currentUser));
  }

  void _navigateToProject(WidgetRef ref, Project project) async {
    Navigator.push(ref.context, MaterialPageRoute(builder: (context) {
      return ProjectDetailPage(
        key: Key(project.id.toString()),
        project: project,
      );
    }));
  }
}
