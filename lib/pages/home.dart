import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:after_layout/after_layout.dart';
import 'package:provider/provider.dart';

import 'package:vikunja_app/components/AddDialog.dart';
import 'package:vikunja_app/components/ErrorDialog.dart';
import 'package:vikunja_app/pages/namespace/namespace.dart';
import 'package:vikunja_app/pages/namespace/namespace_edit.dart';
import 'package:vikunja_app/pages/landing_page.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/namespace.dart';
import 'package:vikunja_app/pages/namespace/overview.dart';
import 'package:vikunja_app/pages/settings.dart';
import 'package:vikunja_app/stores/list_store.dart';

class HomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => HomePageState();
}

class HomePageState extends State<HomePage>  {
  int _selectedDrawerIndex = 0, _previousDrawerIndex = 0;
  bool _loading = true;
  bool _showUserDetails = false;
  Widget? drawerItem;



  Widget _userDetailsWidget(BuildContext context) {
    return ListView(padding: EdgeInsets.zero, children: <Widget>[
      ListTile(
        title: Text('Logout'),
        leading: Icon(Icons.exit_to_app),
        onTap: () {
          VikunjaGlobal.of(context).logoutUser(context);
        },
      ),
      /*ListTile(
        title: Text('Settings'),
        leading: Icon(Icons.settings),
        onTap: () {
          Navigator.push(context,
                  MaterialPageRoute(builder: (context) => SettingsPage()))
              .whenComplete(() => setState(() {
                    //returning from settings, this needs to be force-refreshed
                    drawerItem = _getDrawerItemWidget(_selectedDrawerIndex,
                        forceReload: true);
                  }));
        },
      )*/
    ]);
  }

  List<BottomNavigationBarItem> navbarItems = [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
    BottomNavigationBarItem(icon: Icon(Icons.list), label: "Namespaces"),
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
      appBar: AppBar(
        title: new Text(navbarItems[_selectedDrawerIndex].label ?? "Vikunja"),
        /*actions: _currentNamespace == null
            ? null
            : <Widget>[
                IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => NamespaceEditPage(
                                  namespace: _currentNamespace!,
                                ))).whenComplete(() => _loadNamespaces()))
              ],*/
      ),
      drawer: Drawer(
          child: Column(children: <Widget>[
        UserAccountsDrawerHeader(
          accountName: currentUser != null ? Text(currentUser.username) : null,
          accountEmail: currentUser != null ? Text(currentUser.name) : null,
          currentAccountPicture: currentUser == null
              ? null
              : CircleAvatar(
                  backgroundImage: NetworkImage(currentUser.avatarUrl(context)),
                  ),
          decoration: BoxDecoration(
            image: DecorationImage(
                image: AssetImage("assets/graphics/hypnotize.png"),
                repeat: ImageRepeat.repeat,
                colorFilter: ColorFilter.mode(
                    Theme.of(context).primaryColor, BlendMode.multiply)),
          ),
        ),
        Builder(
            builder: (BuildContext context) => Expanded(
                child: _userDetailsWidget(context))),
        /*Align(
          alignment: FractionalOffset.bottomLeft,
          child: Builder(
            builder: (context) => ListTile(
              leading: Icon(Icons.house),
              onTap: () {
                Navigator.of(context).pop();
                setState(() => _selectedDrawerIndex = -1);
              },
            ),
          ),
        ),
        Align(
          alignment: FractionalOffset.bottomCenter,
          child: Builder(
            builder: (context) => ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add namespace...'),
              onTap: () => _addNamespaceDialog(context),
            ),
          ),
        ),*/
      ])),
      body: drawerItem,
    );
  }

  _getDrawerItemWidget(int pos, {bool forceReload = false}) {
    _previousDrawerIndex = pos;

    switch (pos) {
      case 0:
        return ChangeNotifierProvider<ListProvider>(
          create: (_) => new ListProvider(),
          child: forceReload ? LandingPage(key: UniqueKey()) : LandingPage(),
        );
      case 1:
        return NamespaceOverviewPage();
      case 2:
        return SettingsPage();
    }
    return null;
    if (pos == -1) {
      //return forceReload
      //    ? new LandingPage(key: UniqueKey())
      //    : new LandingPage();

      return ChangeNotifierProvider<ListProvider>(
        create: (_) => new ListProvider(),
        child: forceReload ? LandingPage(key: UniqueKey()) : LandingPage(),
      );
    }
  }




}
