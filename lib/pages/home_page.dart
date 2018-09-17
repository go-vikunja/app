import 'package:flutter/material.dart';
import 'package:fluttering_vikunja/components/GravatarImage.dart';
import 'package:fluttering_vikunja/fragments/namespace.dart';
import 'package:fluttering_vikunja/fragments/placeholder.dart';
import 'package:fluttering_vikunja/global.dart';
import 'package:fluttering_vikunja/models/namespace.dart';
import 'package:fluttering_vikunja/models/task.dart';
import 'package:fluttering_vikunja/models/user.dart';

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

  _addNamespaceDialog() {
    var textController = new TextEditingController();
    showDialog(
      context: context,
      child: new AlertDialog(
        contentPadding: const EdgeInsets.all(16.0),
        content: new Row(children: <Widget>[
          Expanded(
            child: new TextField(
              autofocus: true,
              decoration: new InputDecoration(
                  labelText: 'Namespace', hintText: 'eg. Family Namespace'),
              controller: textController,
            ),
          )
        ]),
        actions: <Widget>[
          new FlatButton(
            child: const Text('CANCEL'),
            onPressed: () => Navigator.pop(context),
          ),
          new FlatButton(
            child: const Text('ADD'),
            onPressed: () {
              if (textController.text.isNotEmpty) {
                _addNamespace(textController.text);
              }
              Navigator.pop(context);
            },
          )
        ],
      ),
    );
  }

  _addNamespace(String name) {
    VikunjaGlobal.of(context)
        .namespaceService
        .create(Namespace(id: null, name: name))
        .then((_) => _updateNamespaces());
  }

  _updateNamespaces() {
    VikunjaGlobal.of(context).namespaceService.getAll().then((result) {
      setState(() {
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
      appBar: AppBar(title: new Text(_currentNamespace?.name ?? 'Vakunja')),
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
            child: ListView(
                padding: EdgeInsets.zero,
                children:
                    ListTile.divideTiles(context: context, tiles: drawerOptions)
                        .toList())),
        new Align(
          alignment: FractionalOffset.bottomCenter,
          child: new ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add namespace...'),
            onTap: () => _addNamespaceDialog(),
          ),
        ),
      ])),
      body: _getDrawerItemWidget(_selectedDrawerIndex),
    );
  }
}
