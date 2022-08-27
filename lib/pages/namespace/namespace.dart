import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:after_layout/after_layout.dart';
import 'package:provider/provider.dart';

import 'package:vikunja_app/components/AddDialog.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/list.dart';
import 'package:vikunja_app/models/namespace.dart';
import 'package:vikunja_app/pages/list/list.dart';
import 'package:vikunja_app/stores/list_store.dart';

class NamespacePage extends StatefulWidget {
  final Namespace namespace;

  NamespacePage({required this.namespace}) : super(key: Key(namespace.id.toString()));

  @override
  _NamespacePageState createState() => new _NamespacePageState();
}

class _NamespacePageState extends State<NamespacePage>
    with AfterLayoutMixin<NamespacePage> {
  List<TaskList> _lists = [];
  bool _loading = true;

  @override
  void afterFirstLayout(BuildContext context) {
    _loadLists();
  }

  /////
  // This essentially shows the lists.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: !this._loading
          ? RefreshIndicator(
              child: _lists.length > 0
                  ? new ListView(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      children: ListTile.divideTiles(
                          context: context,
                          tiles: _lists.map((ls) => Dismissible(
                                key: Key(ls.id.toString()),
                                direction: DismissDirection.startToEnd,
                                child: ListTile(
                                  title: new Text(ls.title ?? ""),
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
                                  _removeList(ls).then((_) =>
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(
                                                  "${ls.title} removed"))));
                                },
                              ))).toList(),
                    )
                  : Center(child: Text('This namespace is empty.')),
              onRefresh: _loadLists,
            )
          : Center(child: CircularProgressIndicator()),
      floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
              onPressed: () => _addListDialog(context),
              child: const Icon(Icons.add))),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLists();
  }

  Future _removeList(TaskList list) {
    return VikunjaGlobal.of(context)
        .listService
        .delete(list.id)
        .then((_) => _loadLists());
  }

  Future<void> _loadLists() {
    // FIXME: This is called even when the tasks on a list are loaded - which is not needed at all
    return VikunjaGlobal.of(context)
        .listService
        .getByNamespace(widget.namespace.id)
        .then((lists) => setState(() {
              this._lists = lists;
              this._loading = false;
            }));
  }

  _openList(BuildContext context, TaskList list) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => ChangeNotifierProvider<ListProvider>(
        create: (_) => new ListProvider(),
        child: ListPage(
          taskList: list,
        ),
      ),
      // ListPage(taskList: list)
    ));
  }

  _addListDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AddDialog(
          onAdd: (name) => _addList(name, context),
          decoration: new InputDecoration(
              labelText: 'List Name', hintText: 'eg. Shopping List')),
    );
  }

  _addList(String name, BuildContext context) {
    VikunjaGlobal.of(context)
        .listService
        .create(widget.namespace.id, TaskList(id: 0, title: name, tasks: []))
        .then((_) {
      setState(() {});
      _loadLists();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('The list was successfully created!'),
        ),
      );
    });
  }
}
