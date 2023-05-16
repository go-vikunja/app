import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:vikunja_app/components/AddDialog.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/list.dart';
import 'package:vikunja_app/models/namespace.dart';
import 'package:vikunja_app/pages/list/list.dart';
import 'package:vikunja_app/stores/list_store.dart';

import '../../components/pagestatus.dart';

class NamespacePage extends StatefulWidget {
  final Namespace namespace;

  NamespacePage({required this.namespace})
      : super(key: Key(namespace.id.toString()));

  @override
  _NamespacePageState createState() => new _NamespacePageState();
}

class _NamespacePageState extends State<NamespacePage> {
  List<TaskList> _lists = [];
  PageStatus namespacestatus = PageStatus.loading;

  /////
  // This essentially shows the lists.
  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (namespacestatus) {
      case PageStatus.built:
        _loadLists();
        body = new Stack(children: [
          ListView(),
          Center(
            child: CircularProgressIndicator(),
          )
        ]);
        break;
      case PageStatus.loading:
        body = new Stack(children: [
          ListView(),
          Center(
            child: CircularProgressIndicator(),
          )
        ]);
        break;
      case PageStatus.error:
        body = new Stack(children: [
          ListView(),
          Center(child: Text("There was an error loading this view"))
        ]);
        break;
      case PageStatus.success:
        body = new ListView(
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
                      _removeList(ls).then((_) => ScaffoldMessenger.of(context)
                          .showSnackBar(
                              SnackBar(content: Text("${ls.title} removed"))));
                    },
                  ))).toList(),
        );
        break;
      case PageStatus.empty:
        body = new Stack(children: [
          ListView(),
          Center(child: Text("This view is empty"))
        ]);
        break;
    }
    return new Scaffold(
      appBar: AppBar(
        title: Text(widget.namespace.title),
      ),
      body: RefreshIndicator(onRefresh: () => _loadLists(), child: body),
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

  Future<void> _removeList(TaskList list) {
    return VikunjaGlobal.of(context)
        .listService
        .delete(list.id)
        .then((_) => _loadLists());
  }

  Future<void> _loadLists() {
    // FIXME: This is called even when the tasks on a list are loaded - which is not needed at all
    namespacestatus = PageStatus.loading;
    return VikunjaGlobal.of(context)
        .listService
        .getByNamespace(widget.namespace.id)
        .then((lists) => setState(() {
              if (lists != null) {
                this._lists = lists;
                namespacestatus = PageStatus.success;
              } else {
                namespacestatus = PageStatus.error;
              }
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

  void _addList(String name, BuildContext context) {
    final curentUser = VikunjaGlobal.of(context).currentUser;
    if (curentUser == null) {
      return;
    }

    VikunjaGlobal.of(context)
        .listService
        .create(
            widget.namespace.id,
            TaskList(
              title: name,
              tasks: [],
              namespaceId: widget.namespace.id,
              owner: curentUser,
            ))
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
