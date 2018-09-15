import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttering_vikunja/pages/list_page.dart';

class NamespaceFragment extends StatefulWidget {
  final String namespace;
  NamespaceFragment({this.namespace}) : super(key: Key(namespace));

  @override
  _NamespaceFragmentState createState() => new _NamespaceFragmentState();
}

class _NamespaceFragmentState extends State<NamespaceFragment> {
  Set<String> _lists = Set.from(
      ["Cupertino List", "Material List", "Shopping List", "NAS List"]);

  @override
  Widget build(BuildContext context) {
    return new ListView(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      children: ListTile.divideTiles(
          context: context,
          tiles: _lists.map((name) => Dismissible(
                key: Key(name),
                direction: DismissDirection.startToEnd,
                child: ListTile(
                  title: new Text(name),
                  onTap: () => _openList(context, name),
                  trailing: Icon(Icons.arrow_right),
                ),
                background: Container(
                  color: Colors.red,
                  child: const ListTile(
                      leading:
                          Icon(Icons.delete, color: Colors.white, size: 36.0)),
                ),
                onDismissed: (direction) {
                  setState(() => _lists.remove(name));
                  Scaffold.of(context)
                      .showSnackBar(SnackBar(content: Text("$name removed")));
                },
              ))).toList(),
    );
  }

  _openList(BuildContext context, String name) {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => ListPage(listName: name)));
  }
}
