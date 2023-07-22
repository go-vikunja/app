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
import 'package:vikunja_app/stores/list_store.dart';

class HomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _selectedDrawerIndex = 0, _previousDrawerIndex = 0;
  Widget? drawerItem;


  List<Widget> widgets = [
    ChangeNotifierProvider<ListProvider>(
      create: (_) => new ListProvider(),
      child: LandingPage(),
    ),
    ProjectOverviewPage(),
    SettingsPage()
  ];

  List<BottomNavigationBarItem> navbarItems = [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
    BottomNavigationBarItem(icon: Icon(Icons.list), label: "Projects"),
    BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
  ];

  @override
  Widget build(BuildContext context) {
    final currentUser = VikunjaGlobal.of(context).currentUser;
    if (_selectedDrawerIndex != _previousDrawerIndex || drawerItem == null)
      drawerItem = _getDrawerItemWidget(_selectedDrawerIndex);

    return new Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        items: navbarItems,
        currentIndex: _selectedDrawerIndex,
        onTap: (index) {
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
