import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:after_layout/after_layout.dart';

import 'package:vikunja_app/components/AddDialog.dart';
import 'package:vikunja_app/components/ErrorDialog.dart';
import 'package:vikunja_app/pages/namespace/namespace.dart';
import 'package:vikunja_app/pages/namespace/namespace_edit.dart';
import 'package:vikunja_app/pages/landing_page.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/namespace.dart';
import 'package:vikunja_app/pages/settings.dart';


class HomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with AfterLayoutMixin<HomePage> {
  List<Namespace> _namespaces = [];

  Namespace get _currentNamespace =>
      _selectedDrawerIndex >= 0 && _selectedDrawerIndex < _namespaces.length
          ? _namespaces[_selectedDrawerIndex]
          : null;
  int _selectedDrawerIndex = -1, _previousDrawerIndex = -1;
  bool _loading = true;
  bool _showUserDetails = false;
  Widget drawerItem;

  @override
  void afterFirstLayout(BuildContext context) {
    _loadNamespaces();
  }

  Widget _namespacesWidget() {
    List<Widget> namespacesList = <Widget>[];
    _namespaces
        .asMap()
        .forEach((i, namespace) => namespacesList.add(new ListTile(
              leading: const Icon(Icons.folder),
              title: new Text(namespace.title),
              selected: i == _selectedDrawerIndex,
              onTap: () => _onSelectItem(i),
            )));

    return this._loading
        ? Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            child: ListView(
                padding: EdgeInsets.zero,
                children: ListTile.divideTiles(
                        context: context, tiles: namespacesList)
                    .toList()),
            onRefresh: _loadNamespaces,
          );
  }

  Widget _userDetailsWidget(BuildContext context) {
    return ListView(padding: EdgeInsets.zero, children: <Widget>[
      ListTile(
        title: Text('Logout'),
        leading: Icon(Icons.exit_to_app),
        onTap: () {
          VikunjaGlobal.of(context).logoutUser(context);
        },
      ),
      ListTile(
        title: Text('Settings'),
        leading: Icon(Icons.settings),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
              builder: (context) => SettingsPage()))
              .whenComplete(() =>
              setState((){
                //returning from settings, this needs to be force-refreshed
                drawerItem = _getDrawerItemWidget(_selectedDrawerIndex, forceReload: true);
          }));
        },
      )
    ]);
  }

  @override
  Widget build(BuildContext context) {
    var currentUser = VikunjaGlobal.of(context).currentUser;
    if(_selectedDrawerIndex != _previousDrawerIndex || drawerItem == null)
      drawerItem = _getDrawerItemWidget(_selectedDrawerIndex);

    return new Scaffold(
      appBar: AppBar(
        title: new Text(_currentNamespace?.title ?? 'Vikunja'),
        actions: _currentNamespace == null
            ? null
            : <Widget>[
                IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => NamespaceEditPage(
                                  namespace: _currentNamespace,
                                ))).whenComplete(() => _loadNamespaces()))
              ],
      ),
      drawer: new Drawer(
          child: new Column(children: <Widget>[
            new UserAccountsDrawerHeader(
          accountEmail:
              currentUser?.email == null ? null : Text(currentUser.email),
          accountName:
              currentUser?.username == null ? null : Text(currentUser.username),
          onDetailsPressed: () {
            setState(() {
              _showUserDetails = !_showUserDetails;
            });
          },
          currentAccountPicture: currentUser == null
              ? null
              : CircleAvatar(
                  //backgroundImage: NetworkImage(currentUser.avatarUrl(context)),
                ),
          decoration: BoxDecoration(
            image: DecorationImage(
                image: AssetImage("assets/graphics/hypnotize.png"),
                repeat: ImageRepeat.repeat,
                colorFilter: ColorFilter.mode(
                    Theme.of(context).primaryColor, BlendMode.multiply)),
          ),
        ),
        new Builder(
            builder: (BuildContext context) => Expanded(
                child: _showUserDetails
                    ? _userDetailsWidget(context)
                    : _namespacesWidget())),
            new Align(
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
        new Align(
          alignment: FractionalOffset.bottomCenter,
          child: Builder(
            builder: (context) => ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add namespace...'),
              onTap: () => _addNamespaceDialog(context),
            ),
          ),
        ),
      ])),
      body: drawerItem,
    );
  }

  _getDrawerItemWidget(int pos, {bool forceReload = false}) {
    _previousDrawerIndex = pos;
    if (pos == -1) {
      return forceReload ? new LandingPage(key: UniqueKey()) : new LandingPage();
    }
    return new NamespacePage(namespace: _namespaces[pos]);
  }

  _onSelectItem(int index) {
    setState(() => _selectedDrawerIndex = index);
    Navigator.of(context).pop();
  }

  _addNamespaceDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (_) => AddDialog(
              onAdd: (name) => _addNamespace(name, context),
              decoration: new InputDecoration(
                  labelText: 'Namespace', hintText: 'eg. Personal Namespace'),
            ));
  }

  _addNamespace(String name, BuildContext context) {
    VikunjaGlobal.of(context)
        .namespaceService
        .create(Namespace(id: null, title: name))
        .then((_) {
      _loadNamespaces();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('The namespace was created successfully!'),
      ));
    }).catchError((error) => showDialog(
            context: context, builder: (context) => ErrorDialog(error: error)));
  }

  Future<void> _loadNamespaces() {
    return VikunjaGlobal.of(context).namespaceService.getAll().then((result) {
      setState(() {
        _loading = false;
        _namespaces = result;
      });
    });
  }
}
