import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/list.dart';

class SettingsPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => SettingsPageState();

}

class SettingsPageState extends State<SettingsPage> {
  List<TaskList>? taskListList;
  int? defaultList;
  bool? ignoreCertificates;
  String? versionTag, newestVersionTag;

  @override
  Widget build(BuildContext context) {
    if(taskListList == null)
      VikunjaGlobal.of(context).listService.getAll().then((value) => setState(() => taskListList = value));
    if(defaultList == null)
      VikunjaGlobal.of(context).listService.getDefaultList().then((value) => setState(() => defaultList = value == null ? null : int.tryParse(value)));
    if(ignoreCertificates == null)
      VikunjaGlobal.of(context).settingsManager.getIgnoreCertificates().then((value) => setState(() => ignoreCertificates = value == "1" ? true:false));
    if(versionTag == null)
      VikunjaGlobal.of(context).versionChecker.getCurrentVersionTag().then((value) => setState(() => versionTag = value));

    return new Scaffold(
      appBar: AppBar(title: Text("Settings"),),
      body: Column(
        children: [
          taskListList != null ?
          ListTile(
            title: Text("Default List"),
            trailing: DropdownButton<int>(
              items: [DropdownMenuItem(child: Text("None"), value: null,), ...taskListList!.map((e) => DropdownMenuItem(child: Text(e.title), value: e.id)).toList()],
              value: defaultList,
              onChanged: (int? value){
                setState(() => defaultList = value);
                VikunjaGlobal.of(context).listService.setDefaultList(value);
                },
            ),) : ListTile(title: Text("..."),),
          ignoreCertificates != null ?
              CheckboxListTile(title: Text("Ignore Certificates"), value: ignoreCertificates, onChanged: (value) {
                setState(() => ignoreCertificates = value);
                VikunjaGlobal.of(context).client.reload_ignore_certs(value);
              }) : ListTile(title: Text("...")),
          TextButton(onPressed: () => VikunjaGlobal.of(context).versionChecker.getLatestVersionTag().then((value) => newestVersionTag = value), child: Text("Check for latest version")),
          Text("Current version: ${versionTag ?? "loading"}"),
          Text(newestVersionTag != null ? "Newest version: $newestVersionTag" : "")
        ],
      ),
    );
  }

}