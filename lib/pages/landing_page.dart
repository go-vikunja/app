import 'package:flutter/material.dart';
import 'package:vikunja_app/global.dart';

import '../components/AddDialog.dart';
import '../models/task.dart';

class LandingPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => LandingPageState();

}

class LandingPageState extends State<LandingPage> {
  int defaultList;
  @override
  Widget build(BuildContext context) {
    VikunjaGlobal.of(context).listService.getDefaultList().then((value) => setState(() => defaultList = value == null ? null : int.tryParse(value)));
    return new Scaffold(
      body: Container(
        padding: EdgeInsets.only(left: 16.0),
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            new Container(
              padding: EdgeInsets.only(top: 32.0),
              child: new Text(
                'Welcome to Vikunja',
                style: Theme.of(context).textTheme.headline4,
              ),
            ),
            new Text('Please select a namespace by tapping the  ☰  icon.',
                style: Theme.of(context).textTheme.subtitle1),
          ],
        )
    ),
        floatingActionButton: Builder(
            builder: (context) =>
                defaultList == null ?
                FloatingActionButton(
                    backgroundColor: Colors.grey,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Please select a default list in the settings'),
                    ));},
                    child: const Icon(Icons.add))
                    :
                    FloatingActionButton(
                      onPressed: () {
                        _addItemDialog(context);
                      },
                      child: const Icon(Icons.add),
                    ),
        ));
  }
  _addItemDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (_) => AddDialog(
            onAdd: (name) => _addItem(name, context),
            decoration: new InputDecoration(
                labelText: 'Task Name', hintText: 'eg. Milk')));
  }

  _addItem(String name, BuildContext context) {
    var globalState = VikunjaGlobal.of(context);
    var newTask = Task(
        id: null, title: name, owner: globalState.currentUser, done: false, loading: true);
    globalState.taskService.add(defaultList, newTask).then((_) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('The task was added successfully!'),
        ));
    });
  }
}
