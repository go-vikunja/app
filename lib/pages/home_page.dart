import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vikunja_app/components/AddDialog.dart';
import 'package:vikunja_app/components/GravatarImage.dart';
import 'package:vikunja_app/fragments/namespace.dart';
import 'package:vikunja_app/fragments/placeholder.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/namespace.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/models/user.dart';

class HomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => new HomePageState();
}

class HomePageState extends State<HomePage> {
  List<Namespace> _namespaces = [];
  Namespace get _currentNamespace =>
      _selectedDrawerIndex >= 0 && _selectedDrawerIndex < _namespaces.length
          ? _namespaces[_selectedDrawerIndex]
          : null;
  int _selectedDrawerIndex = -1;
  bool _loading = true;

  _getDrawerItemWidget(int pos) {
    if (pos == -1) {
      return new PlaceholderFragment();
    }
    return new NamespaceFragment(namespace: _namespaces[pos]);
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
        .create(Namespace(id: null, name: name))
        .then((_) {
          _updateNamespaces();
          Scaffold.of(context).showSnackBar(SnackBar(
            content: Text('The namespace was created successfully!'),
          ));
    });
  }

  Future<void> _updateNamespaces() {
    return VikunjaGlobal.of(context).namespaceService.getAll().then((result) {
      setState(() {
        _loading = false;
        _namespaces = result;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateNamespaces();
  }

  @override
  Widget build(BuildContext context) {
    var currentUser = VikunjaGlobal.of(context).currentUser;
    List<Widget> drawerOptions = <Widget>[];
    _namespaces
        .asMap()
        .forEach((i, namespace) => drawerOptions.add(new ListTile(
              leading: const Icon(Icons.folder),
              title: new Text(namespace.name),
              selected: i == _selectedDrawerIndex,
              onTap: () => _onSelectItem(i),
            )));

    return new Scaffold(
      appBar: AppBar(title: new Text(_currentNamespace?.name ?? 'Vikunja')),
      drawer: new Drawer(
          child: new Column(children: <Widget>[
        new UserAccountsDrawerHeader(
          accountEmail: currentUser == null ? null : Text(currentUser.email),
          accountName: currentUser == null ? null : Text(currentUser.username),
          currentAccountPicture: currentUser == null
              ? null
              : CircleAvatar(
                  backgroundImage: GravatarImageProvider(currentUser.username)),
          decoration: BoxDecoration(
            image: DecorationImage(
                image: AssetImage("assets/graphics/hypnotize.png"),
                repeat: ImageRepeat.repeat,
                colorFilter: ColorFilter.mode(
                    Theme.of(context).primaryColor, BlendMode.multiply)),
          ),
        ),
        new Expanded(
            child: this._loading
                ? Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    child: ListView(
                        padding: EdgeInsets.zero,
                        children: ListTile.divideTiles(
                                context: context, tiles: drawerOptions)
                            .toList()),
                    onRefresh: _updateNamespaces,
                  )),
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
      body: _getDrawerItemWidget(_selectedDrawerIndex),
    );
  }
}
