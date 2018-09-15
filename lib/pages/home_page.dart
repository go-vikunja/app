import 'package:flutter/material.dart';
import 'package:fluttering_vikunja/fragments/namespace.dart';
import 'package:fluttering_vikunja/fragments/placeholder.dart';

class HomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => new HomePageState();
}

class HomePageState extends State<HomePage> {
  List<String> namespaces = ["Jonas's namespace", 'Another namespace'];
  int _selectedDrawerIndex = -1;

  _getDrawerItemWidget(int pos) {
    if (pos == -1) {
      return new PlaceholderFragment();
    }
    return new NamespaceFragment(namespace: namespaces[pos]);
  }

  _onSelectItem(int index) {
    setState(() => _selectedDrawerIndex = index);
    Navigator.of(context).pop();
  }

  _addNamespace() {
    var textController = new TextEditingController();
    showDialog(
        context: context,
        child: new _SystemPadding(
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
                  if (textController.text.isNotEmpty)
                    setState(() => namespaces.add(textController.text));
                  Navigator.pop(context);
                },
              )
            ],
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> drawerOptions = <Widget>[];
    namespaces.asMap().forEach((i, namespace) => drawerOptions.add(new ListTile(
          leading: const Icon(Icons.folder),
          title: new Text(namespace),
          selected: i == _selectedDrawerIndex,
          onTap: () => _onSelectItem(i),
        )));
    return new Scaffold(
      appBar: AppBar(
        title: new Text(_selectedDrawerIndex == -1
            ? 'Vakunja'
            : namespaces[_selectedDrawerIndex]),
      ),
      drawer: new Drawer(
          child: new Column(children: <Widget>[
        new UserAccountsDrawerHeader(
          accountEmail: const Text('jonas@try.vikunja.io'),
          accountName: const Text('Jonas Franz'),
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
            onTap: () => _addNamespace(),
          ),
        ),
      ])),
      body: _getDrawerItemWidget(_selectedDrawerIndex),
    );
  }
}

class _SystemPadding extends StatelessWidget {
  final Widget child;

  _SystemPadding({Key key, this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var mediaQuery = MediaQuery.of(context);
    return new AnimatedContainer(
        padding: mediaQuery.viewInsets,
        duration: const Duration(milliseconds: 300),
        child: child);
  }
}
