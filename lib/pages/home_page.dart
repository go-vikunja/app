import 'package:flutter/material.dart';
import 'package:fluttering_vikunja/fragments/namespace.dart';
import 'package:fluttering_vikunja/fragments/placeholder.dart';

class HomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => new HomePageState();

}

class HomePageState extends State<HomePage> {
  List<String> namespaces = [
    "Jonas's namespace",
    'Another namespace'
  ];
  int _selectedDrawerIndex = -1;

  _getDrawerItemWidget(int pos) {
    if(pos == -1) {
      return new PlaceholderFragment();
    }
    return new NamespaceFragment(namespace: namespaces[pos]);
  }

  _onSelectItem(int index) {
    setState(() => _selectedDrawerIndex = index);
    Navigator.of(context).pop();
  }

  _addNamespace() {
    
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> drawerOptions = <Widget>[];
    namespaces.asMap().forEach((i, namespace) => 
      drawerOptions.add(new ListTile(
        leading: const Icon(Icons.folder),
        title: new Text(namespace),
        selected: i == _selectedDrawerIndex,
        onTap: () => _onSelectItem(i),
      ))
    );
    return new Scaffold(
      appBar: AppBar(
        title: new Text(_selectedDrawerIndex == -1 ? 
        'Vakunja' :
        namespaces[_selectedDrawerIndex]),
      ),
      drawer: new Drawer(
        child: new Column(
          children: <Widget>[
            new UserAccountsDrawerHeader(
              accountEmail: const Text('jonas@try.vikunja.io'),
              accountName: const Text('Jonas Franz'),
            ),
            new Column(
              children: ListTile.divideTiles(context: context, tiles: drawerOptions).toList()
            ),
            new Expanded(
              child: new Align(
                alignment: FractionalOffset.bottomCenter,
                child: new ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Add namespace...'),
                  onTap: () => _addNamespace(),
                ),
              ),
            ),
          ]
        )
      ),
      body: _getDrawerItemWidget(_selectedDrawerIndex),
    );
  }
}