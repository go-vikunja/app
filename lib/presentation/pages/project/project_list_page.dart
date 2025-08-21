import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/presentation/manager/project_controller.dart';
import 'package:vikunja_app/presentation/pages/project/expansion_title.dart';
import 'package:vikunja_app/presentation/pages/project/project_task_list.dart';
import 'package:vikunja_app/presentation/widgets/project/add_project_dialog.dart';

class ProjectOverviewPage extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(projectControllerProvider);

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
              ref.watch(projectControllerProvider.notifier).reload();
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
    if (project.subprojects?.isEmpty == true) {
      return ListTile(
        leading: Icon(Icons.list),
        title: Text(project.title),
        onTap: () {
          _navigateToProject(ref.context, project);
        },
      );
    } else {
      return VikunjaExpansionTile(
        title: Text(project.title),
        children:
            project.subprojects!.map((e) => _buildListItem(ref, e)).toList(),
        onTitleTap: () {
          _navigateToProject(ref.context, project);
        },
      );
    }
  }

  _addProjectDialog(WidgetRef ref) {
    showDialog(
      context: ref.context,
      builder: (_) => AddProjectDialog(
        onAdd: (name) => _addProject(name, ref),
        decoration: new InputDecoration(
            //TODO remove once we also createcd add bucket dialog
            labelText: 'Project',
            hintText: 'eg. Personal Project'),
      ),
    );
  }

  _addProject(String name, WidgetRef ref) async {
    //TODO replace with injection
    final currentUser = await ref.read(userRepositoryProvider).getCurrentUser();

    ref
        .read(projectControllerProvider.notifier)
        .create(Project(title: name, owner: currentUser));
  }

  _navigateToProject(BuildContext context, Project project) {
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return ListPage(
        project: project,
      );
    }));
  }
}
