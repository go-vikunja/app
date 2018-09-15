import 'package:flutter/material.dart';

class ListPage extends StatefulWidget {
  final String listName;

  ListPage({this.listName}) : super(key: Key(listName));

  @override
  _ListPageState createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  Map<String, bool> items = {
    "Butter": true,
    "Milch": false
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: new Text(widget.listName),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        children: ListTile.divideTiles(context: context,
          tiles: items.map((item, checked) =>
            MapEntry(item, CheckboxListTile(
              title: Text(item),
              controlAffinity: ListTileControlAffinity.leading,
              value: checked,
              onChanged: (bool value) => setState(() => items[item] = value),
            ))
          ).values
        ).toList(),
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _addItem(), child: Icon(Icons.add)),
    );
  }

  _addItem() {
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
                    labelText: 'List Item',
                    hintText: 'eg. Milk'),
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
                    setState(() => items[textController.text] = false);
                  Navigator.pop(context);
                },
              )
            ],
          ),
        );
  }
}
