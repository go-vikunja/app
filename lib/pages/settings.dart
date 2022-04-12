import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/list.dart';

class SettingsPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => SettingsPageState();

}

class SettingsPageState extends State<SettingsPage> {
  List<TaskList> taskListList;
  int defaultList;

  @override
  Widget build(BuildContext context) {
    if(taskListList == null)
      VikunjaGlobal.of(context).listService.getAll().then((value) => setState(() => taskListList = value));
    if(defaultList == null)
      VikunjaGlobal.of(context).listService.getDefaultList().then((value) => setState(() => defaultList = value == null ? null : int.tryParse(value)));
    return new Scaffold(
      appBar: AppBar(title: Text("Settings"),),
      body: Column(
        children: [
          taskListList != null ?
          ListTile(
            title: Text("Default List"),
            trailing: DropdownButton(
              items: taskListList.map((e) => DropdownMenuItem(child: Text(e.title), value: e.id)).toList(),
              value: defaultList,
              onChanged: (value){
                setState(() => defaultList = value);
                VikunjaGlobal.of(context).listService.setDefaultList(value);
                },
            ),) : ListTile(title: Text("..."),)
        ],
      ),
    );
  }

}