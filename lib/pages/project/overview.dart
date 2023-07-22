import 'package:after_layout/after_layout.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vikunja_app/pages/project/project.dart';

import '../../components/AddDialog.dart';
import '../../components/ErrorDialog.dart';
import '../../global.dart';
import '../../models/project.dart';

class ProjectOverviewPage extends StatefulWidget {
  @override
  _ProjectOverviewPageState createState() =>
      new _ProjectOverviewPageState();
}

class _ProjectOverviewPageState extends State<ProjectOverviewPage>
    with AfterLayoutMixin<ProjectOverviewPage> {
  List<Project> _projects = [];
  int _selectedDrawerIndex = -2, _previousDrawerIndex = -2;
  bool _loading = true;

  Project? get _currentProject =>
      _selectedDrawerIndex >= -1 && _selectedDrawerIndex < _projects.length
          ? _projects[_selectedDrawerIndex]
          : null;

  @override
  void afterFirstLayout(BuildContext context) {
    _loadProjects();
  }

  Widget createProjectTile(Project project, int level){
    List<Widget> children = addProjectChildren(project, level);
    EdgeInsets insets = EdgeInsets.fromLTRB(level * 20 + 10, 0, 0, 0);
    if(children.length == 0) {
      return new ListTile(
        leading: const Icon(Icons.folder),
        title: new Text(project.title),
        contentPadding: insets,
      );
    } else {
      return new ExpansionTile(
        leading: const Icon(Icons.folder),
        title: new Text(project.title),
        children: children,
        tilePadding: insets
        //onTap: () => _onSelectItem(i),
      );
    }
  }

  List<Widget> addProjectChildren(Project project, level) {
    Iterable<Project> children = _projects.where((element) => element.parentProjectId == project.id);
    List<Widget> widgets = [];
    children.forEach((element) {widgets.add(createProjectTile(element, level + 1));});
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> projectList = <Widget>[];
    _projects
        .asMap()
        .forEach((i, project) {
          if(project.parentProjectId != 0)
            return;
          projectList.add(createProjectTile(project, 0));
        });

    if(_selectedDrawerIndex > -1) {
      return new WillPopScope(
          child: ProjectPage(project: _projects[_selectedDrawerIndex]),
          onWillPop: () async {setState(() {
            _selectedDrawerIndex = -2;
          });
          return false;});

    }

    return Scaffold(
      body:
      this._loading
          ? Center(child: CircularProgressIndicator())
          :
      RefreshIndicator(
        child: ListView(
            padding: EdgeInsets.zero,
            children: ListTile.divideTiles(
                context: context, tiles: projectList)
                .toList()),
        onRefresh: _loadProjects,
      ),
      floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
              onPressed: () => _addProjectDialog(context),
              child: const Icon(Icons.add))),
      appBar: AppBar(
        title: Text("Projects"),
      ),
    );
  }

  Future<void> _loadProjects() {
    return VikunjaGlobal.of(context).projectService.getAll().then((result) {
      setState(() {
        _loading = false;
        if (result != null) _projects = result;
      });
    });
  }

  _onSelectItem(int index) {
    Navigator.push(context,
        MaterialPageRoute(
          builder: (buildContext) => ProjectPage(
            project: _projects[index],
          ),));
    //setState(() => _selectedDrawerIndex = index);
  }

  _addProjectDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (_) => AddDialog(
          onAdd: (name) => _addProject(name, context),
          decoration: new InputDecoration(
              labelText: 'Project', hintText: 'eg. Personal Project'),
        ));
  }

  _addProject(String name, BuildContext context) {
    final currentUser = VikunjaGlobal.of(context).currentUser;
    if (currentUser == null) {
      return;
    }

    VikunjaGlobal.of(context)
        .projectService
        .create(Project(title: name, owner: currentUser))
        .then((_) {
      _loadProjects();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('The project was created successfully!'),
      ));
    }).catchError((error) => showDialog(
        context: context, builder: (context) => ErrorDialog(error: error)));
  }
}
