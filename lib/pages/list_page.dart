import 'package:flutter/material.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/task.dart';

class ListPage extends StatefulWidget {
  final TaskList taskList;

  ListPage({this.taskList}) : super(key: Key(taskList.id.toString()));

  @override
  _ListPageState createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  TaskList items;

  @override
  void initState() {
    items = TaskList(
        id: widget.taskList.id, title: widget.taskList.title, tasks: []);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: new Text(items.title),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        children: ListTile.divideTiles(
                context: context,
                tiles: items?.tasks?.map((task) => CheckboxListTile(
                          title: Text(task.text),
                          controlAffinity: ListTileControlAffinity.leading,
                          value: task.done ?? false,
                          subtitle: task.description == null
                              ? null
                              : Text(task.description),
                          onChanged: (bool value) => _updateTask(task, value),
                        )) ??
                    [])
            .toList(),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () => _addItemDialog(), child: Icon(Icons.add)),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateList();
  }

  _updateTask(Task task, bool checked) {
    // TODO use copyFrom
    VikunjaGlobal.of(context)
        .taskService
        .update(Task(
          id: task.id,
          done: checked,
          text: task.text,
          description: task.description,
          owner: null,
        ))
        .then((_) => _updateList());
  }

  _updateList() {
    VikunjaGlobal.of(context).listService.get(widget.taskList.id).then((tasks) {
      setState(() {
        items = tasks;
      });
    });
  }

  _addItemDialog() {
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
                  labelText: 'List Item', hintText: 'eg. Milk'),
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
              if (textController.text.isNotEmpty) _addItem(textController.text);
              Navigator.pop(context);
            },
          )
        ],
      ),
    );
  }

  _addItem(String name) {
    var globalState = VikunjaGlobal.of(context);
    globalState.taskService
        .add(
            items.id,
            Task(
                id: null,
                text: name,
                owner: globalState.currentUser,
                done: false))
        .then((task) {
      setState(() {
        items.tasks.add(task);
      });
    }).then((_) => _updateList());
  }
}
