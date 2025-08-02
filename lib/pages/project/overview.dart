import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vikunja_app/pages/project/project_task_list.dart';

import '../../components/AddDialog.dart';
import '../../global.dart';
import '../../models/project.dart';
import '../../stores/project_store.dart';

class ProjectOverviewPage extends StatefulWidget {
  @override
  _ProjectOverviewPageState createState() => new _ProjectOverviewPageState();
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

  List<int> expandedList = [];

  @override
  void afterFirstLayout(BuildContext context) {
    _loadProjects();
    VikunjaGlobal.of(context)
        .settingsManager
        .getExpandedProjects()
        .then((val) => setState(() {
              expandedList = val ?? [];
              print("Setting expanded list in setup to $expandedList");
            }));
  }

  void updateExpandedList() {
    VikunjaGlobal.of(context).settingsManager.setExpandedProjects(expandedList);
  }

  void addToExpandedList(int id) {
    expandedList.add(id);
    updateExpandedList();
  }

  void removeFromExpandedList(int id) {
    expandedList.remove(id);
    updateExpandedList();
  }

  Widget createProjectTile(Project project, int level) {
    EdgeInsets insets = EdgeInsets.fromLTRB(level * 10 + 10, 0, 0, 0);

    bool expanded = expandedList.contains(project.id);
    Widget icon;

    List<Widget>? children = addProjectChildren(project, level + 1);
    bool no_children = children.length == 0;
    if (no_children) {
      icon = Icon(Icons.list);
    } else {
      if (expanded) {
        icon = Icon(Icons.arrow_drop_down_sharp);
      } else {
        children = null;
        icon = Icon(Icons.arrow_right_sharp);
      }
    }

    return Column(children: [
      ListTile(
        onTap: () {
          Provider.of<ProjectProvider>(context, listen: false);
          openList(context, project);
        },
        contentPadding: insets,
        leading: IconButton(
          disabledColor: Theme.of(context).unselectedWidgetColor,
          icon: icon,
          onPressed: !no_children
              ? () {
                  setState(() {
                    if (expanded)
                      removeFromExpandedList(project.id);
                    else
                      addToExpandedList(project.id);
                  });
                }
              : null,
        ),
        title: new Text(project.title),
        //onTap: () => _onSelectItem(i),
      ),
      ...?children
    ]);
  }

  List<Widget> addProjectChildren(Project project, level) {
    Iterable<Project> children =
        _projects.where((element) => element.parentProjectId == project.id);
    project.subprojects = children;
    List<Widget> widgets = [];
    children.forEach((element) {
      widgets.add(createProjectTile(element, level + 1));
    });
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> projectList = <Widget>[];
    _projects.asMap().forEach((i, project) {
      if (project.parentProjectId != 0) return;
      projectList.add(createProjectTile(project, 0));
    });

    if (_selectedDrawerIndex > -1) {
      return new WillPopScope(
          child: ListPage(project: _projects[_selectedDrawerIndex]),
          onWillPop: () async {
            setState(() {
              _selectedDrawerIndex = -2;
            });
            return false;
          });
    }

    return Scaffold(
      body: this._loading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              child: ListView(
                  padding: EdgeInsets.zero,
                  children:
                      ListTile.divideTiles(context: context, tiles: projectList)
                          .toList()),
              onRefresh: _loadProjects,
            ),
      appBar: AppBar(
        title: Text("Projects"),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _addProjectDialog(context),
          )
        ],
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
    });
  }
}
