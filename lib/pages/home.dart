import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:after_layout/after_layout.dart';
import 'package:provider/provider.dart';

import 'package:vikunja_app/components/AddDialog.dart';
import 'package:vikunja_app/components/ErrorDialog.dart';
import 'package:vikunja_app/models/project.dart';
import 'package:vikunja_app/pages/namespace/namespace.dart';
import 'package:vikunja_app/pages/namespace/namespace_edit.dart';
import 'package:vikunja_app/pages/landing_page.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/namespace.dart';
import 'package:vikunja_app/pages/namespace/overview.dart';
import 'package:vikunja_app/pages/project/overview.dart';
import 'package:vikunja_app/pages/settings.dart';

import '../stores/project_store.dart';

class HomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _selectedDrawerIndex = 0, _previousDrawerIndex = 0;
  Widget? drawerItem;

  List<Widget> widgets = [
    ChangeNotifierProvider<ProjectProvider>(
      create: (_) => new ProjectProvider(),
      child: LandingPage(),
    ),
    ProjectOverviewPage(),
    SettingsPage()
  ];

  List<NavigationDestination> navbarItems = [
    NavigationDestination(icon: Icon(Icons.home), label: "Home"),
    NavigationDestination(icon: Icon(Icons.list), label: "Projects"),
    NavigationDestination(icon: Icon(Icons.settings), label: "Settings"),
  ];

  @override
  Widget build(BuildContext context) {
    final currentUser = VikunjaGlobal.of(context).currentUser;
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

  _getDrawerItemWidget(int pos, {bool forceReload = false}) {
    _previousDrawerIndex = pos;
    return widgets[pos];
  }
}
