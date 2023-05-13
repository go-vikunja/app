import 'package:after_layout/after_layout.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../components/AddDialog.dart';
import '../../components/ErrorDialog.dart';
import '../../global.dart';
import '../../models/namespace.dart';
import 'namespace.dart';

class NamespaceOverviewPage extends StatefulWidget {
  @override
  _NamespaceOverviewPageState createState() =>
      new _NamespaceOverviewPageState();
}

class _NamespaceOverviewPageState extends State<NamespaceOverviewPage>
    with AfterLayoutMixin<NamespaceOverviewPage> {
  List<Namespace> _namespaces = [];
  int _selectedDrawerIndex = -2, _previousDrawerIndex = -2;
  bool _loading = true;

  Namespace? get _currentNamespace =>
      _selectedDrawerIndex >= -1 && _selectedDrawerIndex < _namespaces.length
          ? _namespaces[_selectedDrawerIndex]
          : null;

  @override
  void afterFirstLayout(BuildContext context) {
    _loadNamespaces();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    List<Widget> namespacesList = <Widget>[];
    _namespaces
        .asMap()
        .forEach((i, namespace) => namespacesList.add(new ListTile(
              leading: const Icon(Icons.folder),
              title: new Text(namespace.title),
              selected: i == _selectedDrawerIndex,
              onTap: () => _onSelectItem(i),
            )));

    if(_selectedDrawerIndex > -1) {
      return new WillPopScope(
          child: NamespacePage(namespace: _namespaces[_selectedDrawerIndex]),
          onWillPop: () async {setState(() {
            _selectedDrawerIndex = -2;
          });
            return false;});

    }

    return this._loading
        ? Center(child: CircularProgressIndicator())
        : Scaffold(
        body: RefreshIndicator(
            child: ListView(
                padding: EdgeInsets.zero,
                children: ListTile.divideTiles(
                        context: context, tiles: namespacesList)
                    .toList()),
            onRefresh: _loadNamespaces,
          ),
    floatingActionButton: Builder(
    builder: (context) => FloatingActionButton(
    onPressed: () => _addNamespaceDialog(context),
    child: const Icon(Icons.add))));
  }

  Future<void> _loadNamespaces() {
    return VikunjaGlobal.of(context).namespaceService.getAll().then((result) {
      setState(() {
        _loading = false;
        if (result != null) _namespaces = result;
      });
    });
  }

  _onSelectItem(int index) {
    setState(() => _selectedDrawerIndex = index);

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
    final currentUser = VikunjaGlobal.of(context).currentUser;
    if (currentUser == null) {
      return;
    }

    VikunjaGlobal.of(context)
        .namespaceService
        .create(Namespace(title: name, owner: currentUser))
        .then((_) {
      _loadNamespaces();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('The namespace was created successfully!'),
      ));
    }).catchError((error) => showDialog(
            context: context, builder: (context) => ErrorDialog(error: error)));
  }
}
