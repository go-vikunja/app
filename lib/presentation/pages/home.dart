import 'package:flutter/material.dart';
import 'package:vikunja_app/presentation/pages/project/project_list_page.dart';
import 'package:vikunja_app/presentation/pages/settings_page.dart';
import 'package:vikunja_app/presentation/pages/task/task_list_page.dart';

class HomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _selectedDrawerIndex = 0, _previousDrawerIndex = 0;
  Widget? drawerItem;

  List<Widget> widgets = [
    TaskListPage(),
    ProjectListPage(),
    SettingsPage()
  ];

  List<NavigationDestination> navbarItems = [
    NavigationDestination(icon: Icon(Icons.home), label: "Home"),
    NavigationDestination(icon: Icon(Icons.list), label: "Projects"),
    NavigationDestination(icon: Icon(Icons.settings), label: "Settings"),
  ];

  @override
  Widget build(BuildContext context) {
    if (_selectedDrawerIndex != _previousDrawerIndex || drawerItem == null)
      drawerItem = _getDrawerItemWidget(_selectedDrawerIndex);

    return new Scaffold(
      bottomNavigationBar: NavigationBar(
        destinations: navbarItems,
        selectedIndex: _selectedDrawerIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedDrawerIndex = index;
          });
        },
      ),
      body: drawerItem,
    );
  }

  _getDrawerItemWidget(int pos) {
    _previousDrawerIndex = pos;
    return widgets[pos];
  }
}
