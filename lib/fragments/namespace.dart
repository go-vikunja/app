import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttering_vikunja/global.dart';
import 'package:fluttering_vikunja/models/namespace.dart';
import 'package:fluttering_vikunja/models/task.dart';
import 'package:fluttering_vikunja/pages/list_page.dart';

class NamespaceFragment extends StatefulWidget {
  final Namespace namespace;
  NamespaceFragment({this.namespace})
      : super(key: Key(namespace.id.toString()));

  @override
  _NamespaceFragmentState createState() => new _NamespaceFragmentState();
}

class _NamespaceFragmentState extends State<NamespaceFragment> {
  List<TaskList> _lists = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: new ListView(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        children: ListTile.divideTiles(
            context: context,
            tiles: _lists.map((ls) => Dismissible(
                  key: Key(ls.id.toString()),
                  direction: DismissDirection.startToEnd,
                  child: ListTile(
                    title: new Text(ls.title),
                    onTap: () => _openList(context, ls),
                    trailing: Icon(Icons.arrow_right),
                  ),
                  background: Container(
                    color: Colors.red,
                    child: const ListTile(
                        leading: Icon(Icons.delete,
                            color: Colors.white, size: 36.0)),
                  ),
                  onDismissed: (direction) {
                    _removeList(ls).then((_) => Scaffold.of(context)
                        .showSnackBar(
                            SnackBar(content: Text("${ls.title} removed"))));
                  },
                ))).toList(),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () => _addListDialog(), child: const Icon(Icons.add)),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateLists();
  }

  Future _removeList(TaskList list) {
    return VikunjaGlobal.of(context)
        .listService
        .delete(list.id)
        .then((_) => _updateLists());
  }

  _updateLists() {
    VikunjaGlobal.of(context)
        .listService
        .getByNamespace(widget.namespace.id)
        .then((lists) => setState(() => this._lists = lists));
  }

  _openList(BuildContext context, TaskList list) {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => ListPage(taskList: list)));
  }

  _addListDialog() {
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
                  labelText: 'List Name', hintText: 'eg. Shopping List'),
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
                _addList(textController.text);
              }
              Navigator.pop(context);
            },
          )
        ],
      ),
    );
  }

  _addList(String name) {
    VikunjaGlobal.of(context)
        .listService
        .create(widget.namespace.id, TaskList(id: null, title: name, tasks: []))
        .then((_) => setState(() {}));
  }
}
